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

class ReclamationResponse {
  final String message;
  final DateTime date;
  final String? audioPath; // URL ou chemin vocal admin

  const ReclamationResponse({
    required this.message,
    required this.date,
    this.audioPath,
  });
}

class Reclamation {
  final int id;
  final ReclamationType type;
  final String sujet;
  final String description;
  final String trajet;
  final DateTime date;
  final ReclamationStatus status;
  final String? autreCategorie;
  final String? imagePath;
  final String? audioPath;
  final String? aiConseil;
  final List<ReclamationResponse> responses;

  const Reclamation({
    required this.id,
    required this.type,
    required this.sujet,
    required this.description,
    required this.trajet,
    required this.date,
    required this.status,
    this.autreCategorie,
    this.imagePath,
    this.audioPath,
    this.aiConseil,
    this.responses = const [],
  });

  String get typeLabel {
    if (type == ReclamationType.autre &&
        autreCategorie != null &&
        autreCategorie!.trim().isNotEmpty) {
      return autreCategorie!.trim();
    }

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
