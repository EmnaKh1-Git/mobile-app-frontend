import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';

class TrajetService extends ChangeNotifier {
  TrajetService._();

  static final TrajetService instance = TrajetService._();

  final List<Trajet> _trajets = [
    Trajet(
      id: 1,
      conducteurId: monId,
      villeDepart: 'Tunis',
      villeArrivee: 'Hammamet',
      dateDepart: DateTime(2026, 10, 24, 8, 30),
      vehicule: 'Peugeot 208',
      placesTotales: 4,
      placesDispo: 2,
    ),
    Trajet(
      id: 2,
      conducteurId: monId,
      villeDepart: 'Ariana (ESPRIT)',
      villeArrivee: 'Sousse',
      dateDepart: DateTime(2026, 10, 25, 17, 00),
      vehicule: 'Renault Clio',
      placesTotales: 4,
      placesDispo: 3,
    ),
    Trajet(
      id: 3,
      conducteurId: monId,
      villeDepart: 'Tunis Centre',
      villeArrivee: 'Pôle Technologique Ghazela',
      dateDepart: DateTime(2026, 10, 20, 7, 45),
      vehicule: 'Peugeot 208',
      placesTotales: 4,
      placesDispo: 1,
    ),
  ];

  List<Trajet> get tousLesTrajets => List.unmodifiable(_trajets);

  List<Trajet> mesTrajets(
    int userId, {
    bool aVenir = false,
  }) {
    final maintenant = DateTime.now();

    return _trajets.where((trajet) {
      if (trajet.conducteurId != userId) {
        return false;
      }

      if (aVenir) {
        return trajet.dateDepart.isAfter(maintenant);
      }

      return true;
    }).toList();
  }
}
