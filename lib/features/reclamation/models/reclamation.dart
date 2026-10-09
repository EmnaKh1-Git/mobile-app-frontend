enum ReclamationType {
  retard,
  conducteur,
  vehicule,
  paiement,
  autre,
}

enum ReclamationStatus {
  enAttente,
  enCours,
  resolue,
}

class Reclamation {
  final int id;
  final ReclamationType type;
  final String sujet;
  final String description;
  final String trajet;
  final DateTime date;
  final ReclamationStatus status;

  const Reclamation({
    required this.id,
    required this.type,
    required this.sujet,
    required this.description,
    required this.trajet,
    required this.date,
    required this.status,
  });

  String get typeLabel {
    switch (type) {
      case ReclamationType.retard:
        return 'Retard';
      case ReclamationType.conducteur:
        return 'Conducteur';
      case ReclamationType.vehicule:
        return 'Véhicule';
      case ReclamationType.paiement:
        return 'Paiement';
      case ReclamationType.autre:
        return 'Autre';
    }
  }

  String get statusLabel {
    switch (status) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
    }
  }
}
