// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/impact_trajets.dart
//  Carte « Votre impact » de l'historique : km partagés, CO₂ évité,
//  argent économisé et badges (calcul dans services/bilan_impact.dart).
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/discussion_trajet.dart';
import '../../../models/trajet.dart';
import '../services/bilan_impact.dart';
import '../services/discussion_service.dart';
import '../services/trajet_service.dart';

const Color _vert = Color(0xFF1B7F55);
const Color _ambre = Color(0xFFF5A623);

/// Bilan de l'utilisateur connecté (trajets terminés)
BilanImpact bilanUtilisateur() {
  final service = TrajetService.instance;
  final discussions = DiscussionService.instance;
  return calculerBilan(
    commeConducteur: service
        .historique(monId)
        .where((t) => t.statut == StatutTrajet.termine)
        .toList(),
    commePassager: [
      for (final id in discussions.trajetsReserves(monId))
        if (service.parId(id) case final t? when t.statut == StatutTrajet.termine)
          if (discussions.reservationDe(id, monId) case final r?
              when r.presence != PresencePassager.absent)
            (trajet: t, places: r.places),
    ],
    note: discussions.noteMoyenne(monId),
  );
}

class CarteImpact extends StatelessWidget {
  const CarteImpact({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = bilanUtilisateur();

    Widget chiffre(String valeur, String libelle) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valeur,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _vert)),
              ),
              const SizedBox(height: 2),
              Text(libelle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, size: 20, color: _vert),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Votre impact',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text('${b.trajets} trajet(s) partagé(s)',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              chiffre('${b.kmPartages.round()} km', 'partagés'),
              chiffre('${b.co2Evite.round()} kg', 'de CO₂ évités'),
              chiffre('${b.economise.round()} DT', 'économisés\ncomme passager'),
            ],
          ),
          if (b.arbres > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _vert.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.park_outlined, size: 18, color: _vert),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autant de CO₂ que ${b.arbres} arbre${b.arbres > 1 ? 's' : ''} '
                      'en absorbe${b.arbres > 1 ? 'nt' : ''} en un an',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _vert),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Badges · ${b.badgesObtenus}/${b.badges.length}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final badge in b.badges) _TuileBadge(badge: badge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TuileBadge extends StatelessWidget {
  final BadgeImpact badge;
  const _TuileBadge({required this.badge});

  static const Map<TypeBadge, IconData> _icones = {
    TypeBadge.premierTrajet: Icons.flag_outlined,
    TypeBadge.habitue: Icons.repeat,
    TypeBadge.ecoCitoyen: Icons.eco_outlined,
    TypeBadge.grandRouleur: Icons.route_outlined,
    TypeBadge.conducteurEtoile: Icons.star_outline,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final couleur = badge.type == TypeBadge.conducteurEtoile ? _ambre : cs.primary;
    final obtenu = badge.obtenu;

    return Tooltip(
      message: '${badge.description}${obtenu ? ' : obtenu !' : ''}',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: 92,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        decoration: BoxDecoration(
          color: obtenu
              ? couleur.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: badge.progression,
                    strokeWidth: 3,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
                    color: obtenu ? couleur : cs.outline,
                  ),
                  Icon(_icones[badge.type],
                      size: 20, color: obtenu ? couleur : cs.outline),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(badge.titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: obtenu ? null : cs.onSurfaceVariant)),
            Text(obtenu ? 'Obtenu' : badge.avancement,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: obtenu ? couleur : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
