// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/tarif_service.dart
//
//  PRIX IDÉAL D'UNE PLACE (covoiturage = partage des frais)
//
//    coût du trajet  = distance × coût au km
//    coût au km      = consommation × prix du carburant + usure
//                    = 7 L/100 km × 2,525 DT/L + 0,05 DT ≈ 0,227 DT/km
//    prix par place  = coût du trajet ÷ (passagers + conducteur)
//                      × majoration (heure de pointe, nuit)
//    arrondi         = au 0,5 DT le plus proche
//    bornes          = 1 DT minimum, plafond 0,5 DT/km (règle du module)
//
//  Exemple : Tunis -> Sousse, 143 km, 3 places
//    143 × 0,227 = 32,4 DT ÷ 4 = 8,1 DT -> prix idéal 8 DT par place
// ============================================================

import 'dart:math' as math;

/// Position du prix choisi par rapport au prix idéal
enum NiveauPrix { gratuit, bas, ideal, eleve, tropCher }

class EstimationPrix {
  final double distanceKm;
  final int places;

  /// Frais de la voiture pour tout le trajet (carburant + usure)
  final double coutTrajet;

  /// Prix recommandé par place
  final double prixIdeal;

  /// Prix maximum autorisé par place (0,5 DT/km)
  final double prixMax;

  /// Majoration appliquée (0.10 = +10 %) et sa raison
  final double majoration;
  final String? motifMajoration;

  const EstimationPrix({
    required this.distanceKm,
    required this.places,
    required this.coutTrajet,
    required this.prixIdeal,
    required this.prixMax,
    this.majoration = 0,
    this.motifMajoration,
  });

  /// Le prix [prix] est-il bas, idéal, élevé… ?
  NiveauPrix niveau(double prix) {
    if (prix <= 0) return NiveauPrix.gratuit;
    if (prixIdeal <= 0) return NiveauPrix.ideal;
    final r = prix / prixIdeal;
    if (r < 0.8) return NiveauPrix.bas;
    if (r <= 1.25) return NiveauPrix.ideal;
    if (r <= 1.6) return NiveauPrix.eleve;
    return NiveauPrix.tropCher;
  }

  /// Part des frais couverte si toutes les places sont vendues à [prix]
  double partCouverte(double prix) =>
      coutTrajet <= 0 ? 0 : (prix * places) / coutTrajet;
}

class TarifService {
  TarifService._();

  /// Prix du litre de sans plomb en Tunisie (DT) — à mettre à jour si besoin
  static const double prixCarburant = 2.525;

  /// Consommation moyenne d'une citadine (L / 100 km)
  static const double consommation = 7.0;

  /// Entretien, pneus, assurance… (DT / km)
  static const double usureParKm = 0.05;

  static const double prixMinimum = 1.0;

  /// Règle de gestion du module (voir Trajet.valider)
  static const double plafondParKm = 0.5;

  /// Pas des boutons − / + (DT)
  static const double pas = 0.5;

  /// Coût au kilomètre pour la voiture = 0,250 DT
  static double get coutParKm => 0.250;

  /// Arrondi au pas (0,5 DT)
  static double arrondir(double prix) => (prix / pas).round() * pas;

  static EstimationPrix estimer({
    required double distanceKm,
    required int places,
    DateTime? depart,
  }) {
    final km = math.max(0.0, distanceKm);
    final passagers = math.max(1, places);
    final cout = km * coutParKm;
    final (taux, motif) = _majoration(depart);

    // Partage équitable : le conducteur paie aussi sa part
    final brut = cout / (passagers + 1) * (1 + taux);

    // Plafond 0,5 DT/km arrondi vers le bas pour rester valide
    final plafond = (km * plafondParKm / pas).floor() * pas;
    final ideal = math.min(arrondir(math.max(prixMinimum, brut)), plafond);

    return EstimationPrix(
      distanceKm: km,
      places: passagers,
      coutTrajet: cout,
      prixIdeal: ideal,
      prixMax: plafond,
      majoration: taux,
      motifMajoration: motif,
    );
  }

  /// Heure de pointe (lun.–ven. 7h–9h et 17h–19h) : +10 %
  /// Nuit (22h–5h) : +15 %
  static (double, String?) _majoration(DateTime? d) {
    if (d == null) return (0.0, null);
    final h = d.hour;
    if (h >= 22 || h < 5) return (0.15, 'Trajet de nuit');
    final semaine = d.weekday <= DateTime.friday;
    if (semaine && ((h >= 7 && h < 9) || (h >= 17 && h < 19))) {
      return (0.10, 'Heure de pointe');
    }
    return (0.0, null);
  }
}
