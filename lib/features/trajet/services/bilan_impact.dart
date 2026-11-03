// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/bilan_impact.dart
//
//  Bilan du covoiturage de l'utilisateur, à partir de ses trajets
//  terminés (comme conducteur et comme passager présent) :
//   - km partagés : distance des trajets faits à plusieurs ;
//   - CO₂ évité : chaque passager laisse sa voiture au garage ;
//   - argent gagné (conducteur) et économisé (passager, par rapport
//     au même trajet seul en voiture) ;
//   - badges, avec leur progression.
//  Calcul pur (sans écran ni base), facile à tester.
// ============================================================

import 'dart:math' as math;

import '../../../models/trajet.dart';

/// Émissions moyennes d'une voiture (kg de CO₂ par km)
const double co2ParKm = 0.12;

/// Coût d'un trajet seul en voiture (carburant + usure), en DT par km
const double coutVoitureParKm = 0.25;

/// CO₂ absorbé par un arbre en un an (kg), pour donner un ordre d'idée
const double co2ParArbreParAn = 25;

enum TypeBadge { premierTrajet, habitue, ecoCitoyen, grandRouleur, conducteurEtoile }

class BadgeImpact {
  final TypeBadge type;
  final String titre;
  final String description;

  /// De 0 à 1 (1 : badge obtenu)
  final double progression;

  /// « 2/10 », « 209/500 km »… (vide si le badge est obtenu)
  final String avancement;

  const BadgeImpact({
    required this.type,
    required this.titre,
    required this.description,
    required this.progression,
    this.avancement = '',
  });

  bool get obtenu => progression >= 1;
}

class BilanImpact {
  final int trajetsConducteur;
  final int trajetsPassager;
  final double kmPartages;
  final double co2Evite;
  final double gagne;
  final double economise;
  final List<BadgeImpact> badges;

  const BilanImpact({
    required this.trajetsConducteur,
    required this.trajetsPassager,
    required this.kmPartages,
    required this.co2Evite,
    required this.gagne,
    required this.economise,
    required this.badges,
  });

  int get trajets => trajetsConducteur + trajetsPassager;

  /// Nombre d'arbres qui absorberaient ce CO₂ en un an
  int get arbres => (co2Evite / co2ParArbreParAn).round();

  int get badgesObtenus => badges.where((b) => b.obtenu).length;
}

/// [commeConducteur] : trajets terminés de l'utilisateur ;
/// [commePassager] : trajets terminés où il était à bord, avec ses places ;
/// [note] : note moyenne reçue des passagers.
BilanImpact calculerBilan({
  required List<Trajet> commeConducteur,
  required List<({Trajet trajet, int places})> commePassager,
  required ({double moyenne, int nombre}) note,
}) {
  var km = 0.0, co2 = 0.0, gagne = 0.0, economise = 0.0;
  var conduits = 0;

  for (final t in commeConducteur) {
    final passagers = t.placesReservees;
    if (passagers <= 0) continue;
    conduits++;
    km += t.distanceKm;
    co2 += t.distanceKm * passagers * co2ParKm;
    gagne += passagers * t.prixPlace;
  }
  for (final (:trajet, :places) in commePassager) {
    km += trajet.distanceKm;
    co2 += trajet.distanceKm * co2ParKm;
    economise += math.max(
        0, trajet.distanceKm * coutVoitureParKm - trajet.prixPlace * places);
  }

  final trajets = conduits + commePassager.length;
  double part(double valeur, double objectif) =>
      math.min(1, valeur / objectif);
  final etoile = note.nombre >= 2 && note.moyenne >= 4.5;

  return BilanImpact(
    trajetsConducteur: conduits,
    trajetsPassager: commePassager.length,
    kmPartages: km,
    co2Evite: co2,
    gagne: gagne,
    economise: economise,
    badges: [
      BadgeImpact(
        type: TypeBadge.premierTrajet,
        titre: 'Premier trajet',
        description: 'Terminer un premier trajet partagé',
        progression: part(trajets.toDouble(), 1),
      ),
      BadgeImpact(
        type: TypeBadge.habitue,
        titre: 'Habitué',
        description: '10 trajets partagés',
        progression: part(trajets.toDouble(), 10),
        avancement: '$trajets/10',
      ),
      BadgeImpact(
        type: TypeBadge.ecoCitoyen,
        titre: 'Éco-citoyen',
        description: '50 kg de CO₂ évités',
        progression: part(co2, 50),
        avancement: '${co2.round()}/50 kg',
      ),
      BadgeImpact(
        type: TypeBadge.grandRouleur,
        titre: 'Grand rouleur',
        description: '500 km partagés',
        progression: part(km, 500),
        avancement: '${km.round()}/500 km',
      ),
      BadgeImpact(
        type: TypeBadge.conducteurEtoile,
        titre: 'Conducteur 5★',
        description: 'Note moyenne d’au moins 4,5 sur 2 avis ou plus',
        progression: etoile ? 1 : math.min(0.9, note.nombre / 2),
        avancement: note.nombre == 0
            ? '0 avis'
            : '${note.moyenne.toStringAsFixed(1)}/5 · ${note.nombre} avis',
      ),
    ],
  );
}
