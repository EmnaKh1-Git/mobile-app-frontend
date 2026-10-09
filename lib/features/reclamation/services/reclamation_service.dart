import 'package:flutter/foundation.dart';

import '../models/reclamation.dart';

class ReclamationService extends ChangeNotifier {
  ReclamationService._();

  static final ReclamationService instance = ReclamationService._();

  final List<Reclamation> _reclamations = [
    Reclamation(
      id: 1,
      type: ReclamationType.retard,
      sujet: 'Retard au départ',
      description:
          'Le conducteur est arrivé avec 20 minutes de retard au point de rendez-vous et n’a pas informé les passagers à temps.',
      trajet: 'Tunis → Sousse',
      date: DateTime(2026, 9, 28, 17, 30),
      status: ReclamationStatus.enCours,
    ),
    Reclamation(
      id: 2,
      type: ReclamationType.vehicule,
      sujet: 'État du véhicule',
      description:
          'La climatisation ne fonctionnait pas durant le trajet, ce qui a rendu le voyage très inconfortable.',
      trajet: 'Bizerte → Tunis',
      date: DateTime(2026, 9, 18, 8, 15),
      status: ReclamationStatus.resolue,
    ),
  ];

  List<Reclamation> get reclamations => List.unmodifiable(_reclamations);

  void ajouter(Reclamation reclamation) {
    _reclamations.insert(0, reclamation);
    notifyListeners();
  }

  void mettreAJourStatut(int id, ReclamationStatus nouveauStatut) {
    final index = _reclamations.indexWhere((reclamation) => reclamation.id == id);
    if (index == -1) {
      return;
    }

    final reclamation = _reclamations[index];
    _reclamations[index] = Reclamation(
      id: reclamation.id,
      type: reclamation.type,
      sujet: reclamation.sujet,
      description: reclamation.description,
      trajet: reclamation.trajet,
      date: reclamation.date,
      status: nouveauStatut,
    );
    notifyListeners();
  }
}
