import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../models/message.dart';

// ============================================================
// ENREGISTREUR VOCAL
// ============================================================

class EnregistreurVocal extends StatefulWidget {
  /// Durée déjà enregistrée, en secondes.
  final int dureeSecondes;

  final VoidCallback onAnnuler;
  final VoidCallback onEnvoyer;

  const EnregistreurVocal({
    super.key,
    required this.dureeSecondes,
    required this.onAnnuler,
    required this.onEnvoyer,
  });

  @override
  State<EnregistreurVocal> createState() =>
      _EnregistreurVocalState();
}

class _EnregistreurVocalState extends State<EnregistreurVocal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.bordure,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentDoux,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent,
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      return Opacity(
                        opacity:
                            0.35 + _animation.value * 0.65,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration:
                              const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 10),

                  Text(
                    formaterDureeVocale(
                      widget.dureeSecondes,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: List.generate(
                            18,
                            (index) {
                              final hauteur =
                                  7 +
                                      (sin(
                                                _animation
                                                        .value *
                                                    2 *
                                                    pi +
                                                index *
                                                    0.7,
                                              ) *
                                              0.5 +
                                          0.5) *
                                          15;
                              return Container(
                                width: 3,
                                height: hauteur,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      AppColors.accent,
                                  borderRadius:
                                      BorderRadius
                                          .circular(2),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.outlined(
              onPressed: widget.onAnnuler,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.accent,
              ),
              tooltip: 'Annuler',
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.primaire,
              ),
              onPressed: widget.onEnvoyer,
              child: const Icon(
                Icons.send,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
