import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme.dart';
import '../../services/fingerprint_recognition_service.dart';

/// Composant interactif de numérisation d'empreinte digitale
/// L'utilisateur doit poser et maintenir son doigt sur le capteur pour que le scan progresse de 0 à 100/100.
class InteractiveFingerprintPad extends StatefulWidget {
  final String? userEmail;
  final bool isEnrollment;
  final ValueChanged<FingerprintSignature> onScanCompleted;
  final VoidCallback? onScanInterrupted;
  final String? promptMessage;

  const InteractiveFingerprintPad({
    super.key,
    this.userEmail,
    this.isEnrollment = false,
    required this.onScanCompleted,
    this.onScanInterrupted,
    this.promptMessage,
  });

  @override
  State<InteractiveFingerprintPad> createState() =>
      _InteractiveFingerprintPadState();
}

class _InteractiveFingerprintPadState extends State<InteractiveFingerprintPad>
    with TickerProviderStateMixin {
  late AnimationController _laserController;
  late AnimationController _pulseController;

  bool _isHolding = false;
  int _progress = 0;
  Timer? _progressTimer;
  String _statusText = 'Posez et maintenez votre doigt sur le capteur';
  bool _isCompleted = false;
  bool _wasInterrupted = false;

  String _selectedFingerSlot = 'index_droit';

  final List<Map<String, double>> _collectedSamples = [];

  @override
  void initState() {
    super.initState();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _laserController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isCompleted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _wasInterrupted = false;
      _progress = 5;
      _statusText = 'Contact détecté. Maintenez le doigt fermement appuyé...';
      _collectedSamples.clear();
    });

    _laserController.repeat(reverse: true);
    _recordSample(event);

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!_isHolding || _isCompleted) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress += 2;
        if (_progress % 20 == 0) {
          HapticFeedback.selectionClick();
        }

        if (_progress < 25) {
          _statusText = 'Analyse de la surface de contact du doigt...';
        } else if (_progress < 55) {
          _statusText = 'Lecture des sillons papillaires et crêtes...';
        } else if (_progress < 85) {
          _statusText = 'Extraction des caractéristiques biométriques uniques...';
        } else if (_progress < 100) {
          _statusText = 'Association cryptographique au compte...';
        } else {
          _progress = 100;
          _isCompleted = true;
          _statusText = widget.isEnrollment
              ? '✓ Empreinte certifiée et enregistrée à 100/100 pour ce compte !'
              : '✓ Scan terminé à 100/100. Comparaison avec le profil...';
        }
      });

      if (_progress >= 100) {
        timer.cancel();
        _laserController.stop();
        HapticFeedback.heavyImpact();

        final signature = FingerprintRecognitionService.instance
            .createSignatureFromSamples(
          samples: _collectedSamples,
          email: widget.userEmail,
          fingerSlot: _selectedFingerSlot,
        );

        widget.onScanCompleted(signature);
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isHolding && !_isCompleted) {
      _recordSample(event);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isCompleted) return;

    _progressTimer?.cancel();
    _laserController.stop();

    if (_progress < 100) {
      HapticFeedback.lightImpact();
      setState(() {
        _isHolding = false;
        _wasInterrupted = true;
        _progress = 0;
        _statusText =
            '⚠️ Doigt retiré trop tôt ! Maintenez votre doigt sur le capteur jusqu\'à 100/100.';
      });
      widget.onScanInterrupted?.call();
    }
  }

  void _recordSample(PointerEvent event) {
    _collectedSamples.add({
      'x': event.localPosition.dx,
      'y': event.localPosition.dy,
      'pressure': event.pressure > 0 ? event.pressure : 0.55,
      'size': event.size > 0 ? event.size : 0.12,
      'radiusMajor': event.radiusMajor > 0 ? event.radiusMajor : 48.0,
      'radiusMinor': event.radiusMinor > 0 ? event.radiusMinor : 32.0,
      'orientation': event.orientation,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sélecteur de doigt (Index / Pouce)
        if (widget.isEnrollment) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.champFond,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bordure),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pan_tool_alt_rounded,
                    size: 16, color: AppColors.texte2),
                const SizedBox(width: 6),
                const Text('Doigt : ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.texte2)),
                DropdownButton<String>(
                  value: _selectedFingerSlot,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaire),
                  items: const [
                    DropdownMenuItem(
                        value: 'index_droit', child: Text('Index Droit')),
                    DropdownMenuItem(
                        value: 'pouce_droit', child: Text('Pouce Droit')),
                    DropdownMenuItem(
                        value: 'index_gauche', child: Text('Index Gauche')),
                    DropdownMenuItem(
                        value: 'pouce_gauche', child: Text('Pouce Gauche')),
                  ],
                  onChanged: _isHolding || _isCompleted
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedFingerSlot = val);
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Zone interactive avec détection de pression tactile
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          child: AnimatedBuilder(
            animation: Listenable.merge([_laserController, _pulseController]),
            builder: (context, child) {
              final pulseScale = _isHolding
                  ? 1.05
                  : (1.0 + (_pulseController.value * 0.04));

              return Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCompleted
                        ? const Color(0xFFDEF7EC)
                        : (_wasInterrupted
                            ? const Color(0xFFFDE8E8)
                            : (_isHolding
                                ? AppColors.primaireDoux
                                : Colors.white)),
                    border: Border.all(
                      color: _isCompleted
                          ? const Color(0xFF31C48D)
                          : (_wasInterrupted
                              ? const Color(0xFFF98080)
                              : AppColors.primaire),
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isCompleted
                                ? const Color(0xFF31C48D)
                                : AppColors.primaire)
                            .withValues(alpha: _isHolding ? 0.35 : 0.18),
                        blurRadius: _isHolding ? 24 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cercle de progression SVG/Radial
                      SizedBox(
                        width: 136,
                        height: 136,
                        child: CircularProgressIndicator(
                          value: _progress / 100.0,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isCompleted
                                ? const Color(0xFF0E9F6E)
                                : (_wasInterrupted
                                    ? const Color(0xFFE02424)
                                    : AppColors.primaire),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),

                      // Icône empreinte
                      _isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF0E9F6E),
                              size: 72,
                            )
                          : Icon(
                              Icons.fingerprint_rounded,
                              color: _wasInterrupted
                                  ? const Color(0xFFE02424)
                                  : (_isHolding
                                      ? AppColors.primaire
                                      : AppColors.primaire
                                          .withValues(alpha: 0.85)),
                              size: 78,
                            ),

                      // Ligne laser de balayage animée
                      if (_isHolding && !_isCompleted)
                        Positioned(
                          top: 15 + (_laserController.value * 105),
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Score 100/100
        Text(
          '$_progress / 100',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: _isCompleted
                ? const Color(0xFF0E9F6E)
                : (_wasInterrupted
                    ? const Color(0xFFE02424)
                    : AppColors.primaire),
          ),
        ),
        const SizedBox(height: 6),

        // Barre linéaire
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress / 100.0,
              minHeight: 8,
              backgroundColor: AppColors.champFond,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isCompleted
                    ? const Color(0xFF0E9F6E)
                    : (_wasInterrupted
                        ? const Color(0xFFE02424)
                        : AppColors.primaire),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Statut textuel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: _isCompleted
                  ? const Color(0xFF03543F)
                  : (_wasInterrupted
                      ? const Color(0xFF9B1C1C)
                      : AppColors.texte),
            ),
          ),
        ),
      ],
    );
  }
}
