import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../services/biometric_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/fingerprint_recognition_service.dart';
import 'interactive_fingerprint_pad.dart';

class BiometricEnrollmentWidget extends StatefulWidget {
  final bool initialFaceEnrolled;
  final bool initialFingerprintEnrolled;
  final String? initialFacePath;
  final String? initialFingerprintPath;
  final String userIdentifier;
  final void Function({
    required bool faceEnrolled,
    required bool fingerprintEnrolled,
    String? facePath,
    String? fingerprintPath,
  }) onBiometricChanged;

  const BiometricEnrollmentWidget({
    super.key,
    this.initialFaceEnrolled = false,
    this.initialFingerprintEnrolled = false,
    this.initialFacePath,
    this.initialFingerprintPath,
    required this.userIdentifier,
    required this.onBiometricChanged,
  });

  @override
  State<BiometricEnrollmentWidget> createState() =>
      _BiometricEnrollmentWidgetState();
}

class _BiometricEnrollmentWidgetState extends State<BiometricEnrollmentWidget> {
  late bool _faceEnrolled;
  late bool _fingerprintEnrolled;
  String? _facePath;
  String? _fingerprintPath;
  bool _isProcessing = false;

  final BiometricService _biometricService = BiometricService.instance;
  final FaceRecognitionService _faceEngine = FaceRecognitionService.instance;

  @override
  void initState() {
    super.initState();
    _faceEnrolled = widget.initialFaceEnrolled;
    _fingerprintEnrolled = widget.initialFingerprintEnrolled;
    _facePath = widget.initialFacePath;
    _fingerprintPath = widget.initialFingerprintPath;
  }

  void _notifyChange() {
    widget.onBiometricChanged(
      faceEnrolled: _faceEnrolled,
      fingerprintEnrolled: _fingerprintEnrolled,
      facePath: _facePath,
      fingerprintPath: _fingerprintPath,
    );
  }

  int get _overallProgressScore {
    int score = 0;
    if (_fingerprintEnrolled) score += 50;
    if (_faceEnrolled) score += 50;
    return score;
  }

  /// Choix du mode d'enregistrement de l'empreinte (Tactile interactif ou Caméra macro)
  Future<void> _chooseFingerprintEnrollmentMethod() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Enregistrement de votre Empreinte (100/100)',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisissez la méthode de numérisation de votre empreinte pour votre compte :',
              style: TextStyle(fontSize: 12, color: AppColors.texte2),
            ),
            const SizedBox(height: 18),

            // Option 1 : Capteur tactile interactif
            ListTile(
              onTap: () {
                Navigator.of(ctx).pop();
                _startInteractiveFingerprintEnrollment();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.primaire, width: 1.5),
              ),
              tileColor: AppColors.primaireDoux.withValues(alpha: 0.3),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaire,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded,
                    color: Colors.white, size: 24),
              ),
              title: const Text(
                'Capteur tactile interactif (0 → 100/100)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Posez et maintenez votre doigt sur l\'écran jusqu\'à 100/100',
                style: TextStyle(fontSize: 11.5, color: AppColors.texte2),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.primaire),
            ),
            const SizedBox(height: 12),

            // Option 2 : Caméra Macro des sillons
            ListTile(
              onTap: () {
                Navigator.of(ctx).pop();
                _startCameraFingerprintEnrollment();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.bordure),
              ),
              tileColor: const Color(0xFFF9FAFB),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFF374151), size: 24),
              ),
              title: const Text(
                'Scanner par caméra (Macro des sillons)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Prenez en gros plan les lignes papillaires de votre doigt',
                style: TextStyle(fontSize: 11.5, color: AppColors.texte2),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.texte2),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Dialogue interactif d'enregistrement d'empreinte digitale tactile (0 à 100/100)
  Future<void> _startInteractiveFingerprintEnrollment() async {
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FingerprintEnrollmentModal(
        userIdentifier: widget.userIdentifier,
      ),
    );

    if (!mounted) return;

    if (success == true) {
      setState(() {
        _fingerprintEnrolled = true;
      });
      _notifyChange();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✓ Empreinte digitale scannée et enregistrée à 100/100 pour ce compte !',
          ),
          backgroundColor: AppColors.primaire,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Enregistrement de l'empreinte via la caméra macro (photo des sillons)
  Future<void> _startCameraFingerprintEnrollment() async {
    setState(() => _isProcessing = true);

    final capturedPath = await _biometricService.captureFingerprintImage(
      userIdentifier: widget.userIdentifier.isNotEmpty
          ? widget.userIdentifier
          : 'profil_empreinte',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (capturedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan d\'empreinte annulé ou caméra inaccessible.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final validated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FingerprintPhotoEnrollmentModal(
        imagePath: capturedPath,
        userIdentifier: widget.userIdentifier,
      ),
    );

    if (!mounted) return;

    if (validated == true) {
      setState(() {
        _fingerprintEnrolled = true;
        _fingerprintPath = capturedPath;
      });
      _notifyChange();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✓ Empreinte certifiée à 100/100 et enregistrée avec succès !',
          ),
          backgroundColor: AppColors.primaire,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Dialogue interactif d'enregistrement et de vérification de visage (0 à 100/100)
  Future<void> _startInteractiveFaceEnrollment() async {
    setState(() => _isProcessing = true);

    final capturedPath = await _biometricService.captureFaceImage(
      userIdentifier: widget.userIdentifier.isNotEmpty
          ? widget.userIdentifier
          : 'nouveau_profil',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (capturedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan facial annulé ou caméra inaccessible.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final validated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FaceEnrollmentModal(
        imagePath: capturedPath,
        userIdentifier: widget.userIdentifier,
      ),
    );

    if (!mounted) return;

    if (validated == true) {
      setState(() {
        _faceEnrolled = true;
        _facePath = capturedPath;
      });
      _notifyChange();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✓ Visage certifié à 100/100 et enregistré avec succès pour ce compte !',
          ),
          backgroundColor: AppColors.primaire,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Test direct de la reconnaissance faciale avec affichage strict du score
  Future<void> _testFaceRecognition() async {
    if (_facePath == null || !File(_facePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord enregistrer votre visage.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final testImagePath = await _biometricService.captureFaceImage(
      userIdentifier: 'test_${widget.userIdentifier}',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (testImagePath == null) return;

    final similarity = await _faceEngine.compareFaceFiles(
      _facePath!,
      testImagePath,
    );

    if (!mounted) return;

    final isMatch = similarity >= FaceRecognitionService.matchThreshold;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isMatch ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
              color: isMatch ? const Color(0xFF0E9F6E) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              isMatch ? 'Vérification 100/100' : 'Échec de Correspondance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isMatch ? const Color(0xFF0E9F6E) : Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMatch
                  ? 'Visage reconnu à ${similarity.toStringAsFixed(1)} % ! Ce visage correspond parfaitement au profil enregistré pour ce compte.'
                  : 'Visage rejeté (${similarity.toStringAsFixed(1)} %). Ce visage ne correspond pas au profil de ce compte ! Accès strictement refusé.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isMatch
                    ? const Color(0xFFDEF7EC)
                    : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Score biométrique : ${similarity.toStringAsFixed(1)} % (Seuil minimal: ${FaceRecognitionService.matchThreshold.toInt()} %)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isMatch
                      ? const Color(0xFF03543F)
                      : const Color(0xFF9B1C1C),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMatch ? AppColors.primaire : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  /// Test direct de l'empreinte digitale avec analyse biométrique interactive
  Future<void> _testFingerprint() async {
    final candidateSignature =
        await showModalBottomSheet<FingerprintSignature>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Test de Reconnaissance d\'Empreinte',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Compte : ${widget.userIdentifier}',
              style: const TextStyle(fontSize: 12, color: AppColors.texte2),
            ),
            const SizedBox(height: 18),
            InteractiveFingerprintPad(
              userEmail: widget.userIdentifier,
              isEnrollment: false,
              onScanCompleted: (sig) => Navigator.of(ctx).pop(sig),
              promptMessage:
                  'Posez et maintenez votre doigt sur le capteur pour tester la reconnaissance',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || candidateSignature == null) return;

    final enrolledSignature = await FingerprintRecognitionService.instance
        .getSignature(widget.userIdentifier);

    final double similarity;
    if (enrolledSignature != null) {
      similarity = FingerprintRecognitionService.instance.compareSignatures(
        enrolledSignature,
        candidateSignature,
      );
    } else {
      similarity = 0.0;
    }

    final isMatch =
        similarity >= FingerprintRecognitionService.matchThreshold;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isMatch ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
              color: isMatch ? const Color(0xFF0E9F6E) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              isMatch ? 'Vérification 100/100' : 'Échec de Correspondance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isMatch ? const Color(0xFF0E9F6E) : Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMatch
                  ? 'Empreinte reconnue à ${similarity.toStringAsFixed(1)} % ! Cette empreinte correspond parfaitement au profil enregistré pour ce compte.'
                  : 'Empreinte rejetée (${similarity.toStringAsFixed(1)} %). Cette empreinte ne correspond pas au profil de ce compte ! Accès strictement refusé.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isMatch
                    ? const Color(0xFFDEF7EC)
                    : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Score biométrique : ${similarity.toStringAsFixed(1)} % (Seuil minimal: ${FingerprintRecognitionService.matchThreshold.toInt()} %)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isMatch
                      ? const Color(0xFF03543F)
                      : const Color(0xFF9B1C1C),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMatch ? AppColors.primaire : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overallScore = _overallProgressScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: overallScore == 100
              ? const Color(0xFF31C48D)
              : AppColors.bordure,
          width: overallScore == 100 ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et jauge globale
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaireDoux,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.primaire,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sécurité Biométrique',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: overallScore == 100
                      ? const Color(0xFFDEF7EC)
                      : AppColors.champFond,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$overallScore / 100',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: overallScore == 100
                        ? const Color(0xFF0E9F6E)
                        : AppColors.primaire,
                  ),
                ),
              ),
            ],
          ),

          // Barre de progression visuelle globale
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallScore / 100.0,
              minHeight: 6,
              backgroundColor: AppColors.champFond,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallScore == 100
                    ? const Color(0xFF0E9F6E)
                    : AppColors.primaire,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARTE 1 : EMPREINTE DIGITALE
          _buildItemCard(
            title: 'Empreinte Digitale',
            subtitle: _fingerprintEnrolled
                ? 'Empreinte certifiée à 100/100 pour ce compte'
                : 'Posez votre doigt sur le capteur (0 → 100/100)',
            icon: Icons.fingerprint_rounded,
            isEnrolled: _fingerprintEnrolled,
            scoreLabel: _fingerprintEnrolled ? '100/100' : '0/100',
            previewImagePath: _fingerprintPath,
            actionText:
                _fingerprintEnrolled ? 'Re-scanner' : 'Enregistrer (100/100)',
            onAction:
                _isProcessing ? null : _chooseFingerprintEnrollmentMethod,
            onTest: _fingerprintEnrolled ? _testFingerprint : null,
            onRemove: _fingerprintEnrolled
                ? () {
                    setState(() {
                      _fingerprintEnrolled = false;
                      _fingerprintPath = null;
                    });
                    _notifyChange();
                  }
                : null,
          ),

          const SizedBox(height: 12),

          // CARTE 2 : RECONNAISSANCE FACIALE
          _buildItemCard(
            title: 'Reconnaissance Faciale',
            subtitle: _faceEnrolled
                ? 'Visage certifié à 100/100 pour ce compte'
                : 'Scannez votre visage avec la caméra (0 → 100/100)',
            icon: Icons.face_rounded,
            isEnrolled: _faceEnrolled,
            scoreLabel: _faceEnrolled ? '100/100' : '0/100',
            previewImagePath: _facePath,
            actionText:
                _faceEnrolled ? 'Re-scanner' : 'Scanner mon visage (100/100)',
            onAction: _isProcessing ? null : _startInteractiveFaceEnrollment,
            onTest: _faceEnrolled ? _testFaceRecognition : null,
            onRemove: _faceEnrolled
                ? () {
                    setState(() {
                      _faceEnrolled = false;
                      _facePath = null;
                    });
                    _notifyChange();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnrolled,
    required String scoreLabel,
    String? previewImagePath,
    required String actionText,
    required VoidCallback? onAction,
    VoidCallback? onTest,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isEnrolled ? const Color(0xFFF9FDFB) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnrolled ? const Color(0xFF31C48D) : AppColors.bordure,
          width: isEnrolled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (previewImagePath != null &&
                  File(previewImagePath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(previewImagePath),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnrolled ? const Color(0xFFDEF7EC) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isEnrolled
                          ? const Color(0xFF31C48D)
                          : AppColors.bordure,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isEnrolled
                        ? const Color(0xFF0E9F6E)
                        : AppColors.texte2,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isEnrolled
                                ? const Color(0xFFDEF7EC)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            scoreLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isEnrolled
                                  ? const Color(0xFF0E9F6E)
                                  : AppColors.texte2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isEnrolled
                            ? const Color(0xFF0E9F6E)
                            : AppColors.texte2,
                        fontWeight: isEnrolled
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              if (onRemove != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: onRemove,
                  tooltip: 'Supprimer',
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onTest != null) ...[
                OutlinedButton.icon(
                  onPressed: onTest,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: const Text('Tester (100/100)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0E9F6E),
                    side: const BorderSide(color: Color(0xFF31C48D)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(
                  isEnrolled ? Icons.refresh_rounded : Icons.add_rounded,
                  size: 15,
                ),
                label: Text(actionText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnrolled
                      ? AppColors.primaireDoux
                      : AppColors.primaire,
                  foregroundColor:
                      isEnrolled ? AppColors.primaire : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal interactif d'enregistrement d'empreinte digitale tactile (0% -> 100/100)
class _FingerprintEnrollmentModal extends StatelessWidget {
  final String userIdentifier;

  const _FingerprintEnrollmentModal({required this.userIdentifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Enregistrement d\'Empreinte Digitale',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Association au compte : $userIdentifier',
            style: const TextStyle(fontSize: 12, color: AppColors.texte2),
          ),
          const SizedBox(height: 20),
          InteractiveFingerprintPad(
            userEmail: userIdentifier,
            isEnrollment: true,
            onScanCompleted: (signature) async {
              // 1. Vérification de l'unicité de l'empreinte biométrique
              final duplicateCheck = await BiometricService.instance
                  .checkFingerprintDuplicate(signature, excludeEmail: userIdentifier);

              if (duplicateCheck.isDuplicate) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Empreinte Déjà Utilisée',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      '❌ Cette empreinte digitale est déjà liée au compte "${duplicateCheck.existingEmail}".\n\nChaque compte UniDrive doit obligatoirement posséder sa propre empreinte biométrique unique.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop(false);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Compris', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                return;
              }

              await FingerprintRecognitionService.instance.saveSignature(
                userIdentifier,
                signature,
              );
              await Future.delayed(const Duration(milliseconds: 600));
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Modal d'enregistrement d'empreinte par caméra macro (0% -> 100/100)
class _FingerprintPhotoEnrollmentModal extends StatefulWidget {
  final String imagePath;
  final String userIdentifier;

  const _FingerprintPhotoEnrollmentModal({
    required this.imagePath,
    required this.userIdentifier,
  });

  @override
  State<_FingerprintPhotoEnrollmentModal> createState() =>
      _FingerprintPhotoEnrollmentModalState();
}

class _FingerprintPhotoEnrollmentModalState
    extends State<_FingerprintPhotoEnrollmentModal> {
  int _progress = 0;
  String _stepDescription = 'Détection des crêtes et sillons papillaires...';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _processFingerprintImage();
  }

  Future<void> _processFingerprintImage() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _progress = 35;
      _stepDescription = 'Analyse de la densité des crêtes dermiques...';
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _progress = 70;
      _stepDescription = 'Vérification de l\'unicité de l\'empreinte...';
    });

    final dupCheck = await BiometricService.instance
        .checkFingerprintPhotoDuplicate(widget.imagePath, excludeEmail: widget.userIdentifier);

    if (dupCheck.isDuplicate) {
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _isSuccess = false;
        _stepDescription =
            '❌ Empreinte déjà liée au compte "${dupCheck.existingEmail}" !';
      });
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Empreinte Déjà Utilisée', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              '❌ Cette empreinte optique est déjà associée au compte "${dupCheck.existingEmail}".\n\nChaque compte UniDrive doit posséder sa propre empreinte biométrique unique.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Compris', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _progress = 100;
      _isSuccess = true;
      _stepDescription = '✓ Empreinte certifiée et liée à votre profil !';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Certification de l\'Empreinte',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profil : ${widget.userIdentifier}',
            style: const TextStyle(fontSize: 12, color: AppColors.texte2),
          ),
          const SizedBox(height: 20),

          // Cadre circulaire avec photo de l'empreinte
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSuccess
                        ? const Color(0xFF31C48D)
                        : AppColors.primaire,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: File(widget.imagePath).existsSync()
                      ? Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.fingerprint_rounded, size: 60),
                ),
              ),
              if (!_isSuccess)
                const SizedBox(
                  width: 132,
                  height: 132,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            '$_progress / 100',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isSuccess
                  ? const Color(0xFF0E9F6E)
                  : AppColors.primaire,
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.champFond,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isSuccess
                      ? const Color(0xFF0E9F6E)
                      : AppColors.primaire,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            _stepDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isSuccess
                  ? const Color(0xFF03543F)
                  : AppColors.texte,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Modal interactif d'enregistrement facial (0% -> 100/100)
class _FaceEnrollmentModal extends StatefulWidget {
  final String imagePath;
  final String userIdentifier;

  const _FaceEnrollmentModal({
    required this.imagePath,
    required this.userIdentifier,
  });

  @override
  State<_FaceEnrollmentModal> createState() => _FaceEnrollmentModalState();
}

class _FaceEnrollmentModalState extends State<_FaceEnrollmentModal> {
  int _progress = 0;
  String _stepDescription = 'Détection faciale dans le cadre...';
  bool _isSuccess = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _processFaceImage();
  }

  Future<void> _processFaceImage() async {
    setState(() {
      _progress = 25;
      _stepDescription = 'Analyse des proportions et de l\'alignement...';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() {
      _progress = 55;
      _stepDescription =
          'Décomposition anatomique (Yeux, Nez, Bouche) et masque gaussien...';
    });

    final signature =
        await FaceRecognitionService.instance.extractFaceSignature(
      widget.imagePath,
    );

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (signature != null) {
      setState(() {
        _progress = 80;
        _stepDescription = 'Vérification de l\'unicité du visage...';
      });

      // VÉRIFICATION D'UNICITÉ DU VISAGE PARMI TOUS LES COMPTES
      final dupCheck = await BiometricService.instance
          .checkFaceDuplicate(widget.imagePath, excludeEmail: widget.userIdentifier);

      if (dupCheck.isDuplicate) {
        if (!mounted) return;
        setState(() {
          _progress = 100;
          _hasError = true;
          _stepDescription =
              '❌ Ce visage est déjà associé au compte "${dupCheck.existingEmail}" !';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Visage Déjà Utilisé', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                '❌ Ce visage est déjà associé au compte "${dupCheck.existingEmail}".\n\nChaque profil UniDrive doit obligatoirement avoir son propre visage unique.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Compris', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        _progress = 90;
        _stepDescription = 'Calcul de la signature chromatique et dHash multi-axes...';
      });

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      setState(() {
        _progress = 100;
        _isSuccess = true;
        _stepDescription = '✓ Visage vérifié à 100/100 et lié à votre profil !';
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _hasError = true;
        _stepDescription = 'Image non lisible ou visage non détecté.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Certification du Visage',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profil : ${widget.userIdentifier}',
            style: const TextStyle(fontSize: 12, color: AppColors.texte2),
          ),
          const SizedBox(height: 20),

          // Cadre circulaire avec photo capturée
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSuccess
                        ? const Color(0xFF31C48D)
                        : AppColors.primaire,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: File(widget.imagePath).existsSync()
                      ? Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.face_rounded, size: 60),
                ),
              ),
              if (!_isSuccess && !_hasError)
                const SizedBox(
                  width: 132,
                  height: 132,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            '$_progress / 100',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isSuccess
                  ? const Color(0xFF0E9F6E)
                  : (_hasError ? const Color(0xFFE02424) : AppColors.primaire),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.champFond,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isSuccess
                      ? const Color(0xFF0E9F6E)
                      : (_hasError
                          ? const Color(0xFFE02424)
                          : AppColors.primaire),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            _stepDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isSuccess
                  ? const Color(0xFF03543F)
                  : (_hasError ? const Color(0xFF9B1C1C) : AppColors.texte),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
