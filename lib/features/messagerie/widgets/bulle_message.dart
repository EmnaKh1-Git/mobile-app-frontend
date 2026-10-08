import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/utils/helpers.dart';

import '../models/message.dart';

// ============================================================
// BULLE DE MESSAGE
// ============================================================

class BulleMessage extends StatelessWidget {
  final Message message;

  /// Affiche le nom de l'expéditeur au-dessus de la bulle
  /// (conversations de groupe uniquement).
  final bool afficherNom;

  const BulleMessage({
    super.key,
    required this.message,
    this.afficherNom = false,
  });

  // ---------------------------------------------------------
  // MESSAGE SYSTÈME (centré, pastille grise)
  // ---------------------------------------------------------

  Widget _messageSysteme() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.bordure,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.contenu,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.texte2,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // MESSAGE NORMAL (bulle)
  // ---------------------------------------------------------

  Widget _bulle() {
    final mien = message.estMien;
    final nomVisible = afficherNom && !mien;

    return Row(
      mainAxisAlignment: mien
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              6,
            ),
            decoration: BoxDecoration(
              color: mien
                  ? AppColors.primaire
                  : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(
                  mien ? 18 : 4,
                ),
                bottomRight: Radius.circular(
                  mien ? 4 : 18,
                ),
              ),
              border: mien
                  ? null
                  : Border.all(
                      color: AppColors.bordure,
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (nomVisible) ...[
                  Text(
                    message.expediteurNom,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaire,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                Text(
                  message.contenu,
                  style: TextStyle(
                    fontSize: 14,
                    color: mien
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                // Heure + statut (✓ / ✓✓)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fHeure(message.dateEnvoi),
                      style: TextStyle(
                        fontSize: 11,
                        color: mien
                            ? Colors.white70
                            : AppColors.texte2,
                      ),
                    ),

                    if (mien) ...[
                      const SizedBox(width: 5),
                      Text(
                        message.statut ==
                                StatutMessage.lu
                            ? '✓✓'
                            : '✓',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.estSysteme) return _messageSysteme();
    return _bulle();
  }
}
