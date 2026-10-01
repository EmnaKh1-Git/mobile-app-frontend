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
      dateDepart: DateTime(2026, 10, 10, 8, 30),
      vehicule: 'Peugeot 208',
      placesTotales: 4,
      placesDispo: 2,
    ),
  ];

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