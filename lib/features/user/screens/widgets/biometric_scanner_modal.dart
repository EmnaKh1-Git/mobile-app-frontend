import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../services/biometric_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/fingerprint_recognition_service.dart';
import 'interactive_fingerprint_pad.dart';

enum BiometricScannerMode { choice, fingerprint, face }

class BiometricScannerModal extends StatefulWidget {
  final BiometricScannerMode initialMode;
  final String? targetEmail;
  final String? enrolledFacePath;
  final ValueChanged<bool>? onAuthenticationComplete;
  final ValueChanged<BiometricAuthResult>? onAuthenticationResult;

  const BiometricScannerModal({
    super.key,
    this.initialMode = BiometricScannerMode.choice,
    this.targetEmail,
    this.enrolledFacePath,
    this.onAuthenticationComplete,
    this.onAuthenticationResult,
  });

  static Future<BiometricAuthResult?> show(
    BuildContext context, {
    BiometricScannerMode initialMode = BiometricScannerMode.choice,
    String? targetEmail,
    String? enrolledFacePath,
  }) async {
    return await showModalBottomSheet<BiometricAuthResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BiometricScannerModal(
        initialMode: initialMode,
        targetEmail: targetEmail,
        enrolledFacePath: enrolledFacePath,
      ),
    );
  }

  @override
  State<BiometricScannerModal> createState() => _BiometricScannerModalState();
}

class _BiometricScannerModalState extends State<BiometricScannerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BiometricService _biometricService = BiometricService.instance;

  bool _isScanning = false;
  bool _isSuccess = false;
  String? _statusMessage;
  String? _capturedFacePath;
  double _similarityScore = 0.0;
  bool _hasAttempted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialMode == BiometricScannerMode.face ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleFingerprintScanCompleted(
    FingerprintSignature candidateSignature,
  ) async {
    setState(() {
      _isScanning = true;
      _hasAttempted = true;
      _statusMessage = 'Vérification biométrique avec le profil du compte...';
    });

    final BiometricAuthResult result;
    if (widget.targetEmail != null && widget.targetEmail!.trim().isNotEmpty) {
      result = await _biometricService.verifyFingerprintForAccount(
        candidateSignature: candidateSignature,
        targetEmail: widget.targetEmail!,
      );
    } else {
      result = await _biometricService.identifyFingerprintAcrossAllAccounts(
        candidateSignature: candidateSignature,
      );
    }

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isScanning = false;
        _isSuccess = true;
        _similarityScore = result.similarityScore ?? 95.0;
        _statusMessage = result.message;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        widget.onAuthenticationComplete?.call(true);
        widget.onAuthenticationResult?.call(result);
        Navigator.of(context).pop(result);
      }
    } else {
      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _similarityScore = result.similarityScore ?? 0.0;
        _statusMessage = result.message;
      });
    }
  }

  Future<void> _scanFingerprintWithCamera() async {
    setState(() {
      _isScanning = true;
      _hasAttempted = true;
      _statusMessage = 'Ouverture de la caméra pour l\'empreinte...';
    });

    final path = await _biometricService.captureFingerprintImage(
      userIdentifier: widget.targetEmail ?? 'auth_fp',
    );

    if (!mounted) return;

    if (path != null) {
      setState(() {
        _statusMessage = 'Analyse des sillons et crêtes de l\'empreinte...';
      });

      final BiometricAuthResult result;
      if (widget.targetEmail != null && widget.targetEmail!.trim().isNotEmpty) {
        result = await _biometricService.verifyFingerprintImageForAccount(
          candidateImagePath: path,
          targetEmail: widget.targetEmail!,
        );
      } else {
        result = await _biometricService.identifyFingerprintImageAcrossAllAccounts(
          candidateImagePath: path,
        );
      }

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isScanning = false;
          _isSuccess = true;
          _similarityScore = result.similarityScore ?? 95.0;
          _statusMessage = result.message;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          widget.onAuthenticationComplete?.call(true);
          widget.onAuthenticationResult?.call(result);
          Navigator.of(context).pop(result);
        }
      } else {
        setState(() {
          _isScanning = false;
          _isSuccess = false;
          _similarityScore = result.similarityScore ?? 0.0;
          _statusMessage = result.message;
        });
      }
    } else {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan d\'empreinte annulé.';
      });
    }
  }

  Future<void> _scanFaceWithCamera() async {
    setState(() {
      _isScanning = true;
      _hasAttempted = true;
      _statusMessage = 'Ouverture de la caméra frontale...';
    });

    final path = await _biometricService.captureFaceImage(
      userIdentifier: widget.targetEmail ?? 'auth_verify',
    );

    if (!mounted) return;

    if (path != null) {
      setState(() {
        _capturedFacePath = path;
        _statusMessage = 'Analyse mathématique des traits du visage...';
      });

      final BiometricAuthResult result;
      if (widget.targetEmail != null && widget.targetEmail!.trim().isNotEmpty) {
        result = await _biometricService.verifyFaceForAccount(
          candidateImagePath: path,
          targetEmail: widget.targetEmail!,
        );
      } else {
        result = await _biometricService.identifyFaceAcrossAllAccounts(
          candidateImagePath: path,
        );
      }

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isScanning = false;
          _isSuccess = true;
          _similarityScore = result.similarityScore ?? 95.0;
          _statusMessage = result.message;
        });

        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onAuthenticationComplete?.call(true);
          widget.onAuthenticationResult?.call(result);
          Navigator.of(context).pop(result);
        }
      } else {
        setState(() {
          _isScanning = false;
          _isSuccess = false;
          _similarityScore = result.similarityScore ?? 0.0;
          _statusMessage = result.message;
        });
      }
    } else {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan facial annulé ou caméra non accessible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget =
        widget.targetEmail != null && widget.targetEmail!.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // En-tête avec titre et badge de compte cible
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaireDoux,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: AppColors.primaire,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Authentification Biométrique',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            hasTarget
                                ? 'Compte : ${widget.targetEmail}'
                                : 'Identification de votre compte',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.texte2,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.texte2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Onglets : Empreinte Digitale / Reconnaissance Faciale
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.champFond,
              borderRadius: BorderRadius.circular(22),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primaire,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaire.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.texte2,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Empreinte'),
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.face_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Visage'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contenu selon l'onglet sélectionné
          SizedBox(
            height: 295,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFingerprintView(),
                _buildFaceView(),
              ],
            ),
          ),

          // Message de statut et score
          if (_statusMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0xFFDEF7EC)
                    : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isSuccess
                      ? const Color(0xFF31C48D)
                      : const Color(0xFFF98080),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 20,
                    color: _isSuccess
                        ? const Color(0xFF0E9F6E)
                        : const Color(0xFFE02424),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _isSuccess
                            ? const Color(0xFF03543F)
                            : const Color(0xFF9B1C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildFingerprintView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InteractiveFingerprintPad(
            userEmail: widget.targetEmail,
            isEnrollment: false,
            onScanCompleted: _handleFingerprintScanCompleted,
            promptMessage:
                'Posez et maintenez votre doigt sur le capteur pour vous authentifier',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _scanFingerprintWithCamera,
            icon: const Icon(Icons.camera_alt_rounded, size: 15),
            label: const Text('Ou scanner l\'empreinte par caméra (Macro)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaire,
              side: const BorderSide(color: AppColors.primaire),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSuccess
                    ? const Color(0xFFDEF7EC)
                    : (_hasAttempted && !_isSuccess
                        ? const Color(0xFFFDE8E8)
                        : AppColors.champFond),
                border: Border.all(
                  color: _isSuccess
                      ? const Color(0xFF31C48D)
                      : (_hasAttempted && !_isSuccess
                          ? const Color(0xFFF98080)
                          : AppColors.primaire),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaire.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _capturedFacePath != null &&
                        File(_capturedFacePath!).existsSync()
                    ? Image.file(
                        File(_capturedFacePath!),
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Icon(
                          _isSuccess
                              ? Icons.verified_user_rounded
                              : (_hasAttempted && !_isSuccess
                                  ? Icons.no_accounts_rounded
                                  : Icons.face_rounded),
                          color: _isSuccess
                              ? const Color(0xFF0E9F6E)
                              : (_hasAttempted && !_isSuccess
                                  ? const Color(0xFFE02424)
                                  : AppColors.primaire),
                          size: 54,
                        ),
                      ),
              ),
            ),
            if (_isScanning)
              const SizedBox(
                width: 114,
                height: 114,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Reconnaissance Faciale',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        if (_similarityScore > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _similarityScore >= FaceRecognitionService.matchThreshold
                  ? const Color(0xFFDEF7EC)
                  : const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Correspondance : ${_similarityScore.toStringAsFixed(1)} %  (Seuil requis: ${FaceRecognitionService.matchThreshold.toInt()}%)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _similarityScore >= FaceRecognitionService.matchThreshold
                    ? const Color(0xFF03543F)
                    : const Color(0xFF9B1C1C),
              ),
            ),
          )
        else
          const Text(
            'Placez votre visage face à la caméra frontale',
            style: TextStyle(fontSize: 12, color: AppColors.texte2),
          ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _isScanning ? null : _scanFaceWithCamera,
          icon: const Icon(Icons.camera_alt_rounded, size: 18),
          label: Text(
            _hasAttempted && !_isSuccess
                ? 'Reprendre une photo / Réessayer'
                : 'Scanner mon visage',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasAttempted && !_isSuccess
                ? const Color(0xFFE02424)
                : AppColors.primaire,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 11,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}
