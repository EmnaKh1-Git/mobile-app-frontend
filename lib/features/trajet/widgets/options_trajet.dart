// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/options_trajet.dart
//  Pastilles des préférences d'un trajet (Entre filles, Non-fumeur,
//  Bagages, Animaux, Réservation instantanée, Régulier), affichées
//  sur les cartes de trajet.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/trajet.dart';

const Color _rose = Color(0xFFC2185B);

class PastillesOptions extends StatelessWidget {
  final Trajet trajet;

  /// false : seulement ce qui distingue le trajet (Entre filles, Régulier)
  final bool toutes;

  const PastillesOptions({super.key, required this.trajet, this.toutes = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final pastilles = [
      if (t.entreFilles) (Icons.woman, 'Entre filles', _rose),
      if (t.estRegulier) (Icons.repeat, 'Régulier', cs.primary),
      if (toutes) ...[
        if (!t.fumeur) (Icons.smoke_free, 'Non-fumeur', cs.onSurfaceVariant),
        if (t.bagages) (Icons.luggage, 'Bagages', cs.onSurfaceVariant),
        if (t.animaux) (Icons.pets, 'Animaux', cs.onSurfaceVariant),
        if (t.reservationAuto)
          (Icons.flash_on, 'Instantanée', cs.onSurfaceVariant),
      ],
    ];
    if (pastilles.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (icone, libelle, couleur) in pastilles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 13, color: couleur),
                const SizedBox(width: 4),
                Text(libelle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: couleur)),
              ],
            ),
          ),
      ],
    );
  }
}
