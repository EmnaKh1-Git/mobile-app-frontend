import 'package:flutter/material.dart';

enum ReclamationType {
  retard,
  conducteur,
  vehicule,
  paiement,
  autre;

  String get label {
    switch (this) {
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

  static ReclamationType? depuisLibelle(String? valeur) {
    final v = (valeur ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    for (final type in ReclamationType.values) {
      if (type.name == v || type.label.toLowerCase() == v) return type;
    }
    if (v.startsWith('v')) return ReclamationType.vehicule;
    return null;
  }
}

enum ReclamationStatus {
  enAttente,
  enCours,
  resolue,
  rejetee;

  String get label {
    switch (this) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
      case ReclamationStatus.rejetee:
        return 'Rejetée';
    }
  }

  /// Une réclamation clôturée ne compte plus dans la charge de travail.
  bool get estCloturee =>
      this == ReclamationStatus.resolue || this == ReclamationStatus.rejetee;

  /// Règles de transition du workflow de traitement.
  Set<ReclamationStatus> get transitionsAutorisees {
    switch (this) {
      case ReclamationStatus.enAttente:
        return {ReclamationStatus.enCours, ReclamationStatus.rejetee};
      case ReclamationStatus.enCours:
        return {
          ReclamationStatus.enAttente,
          ReclamationStatus.resolue,
          ReclamationStatus.rejetee,
        };
      case ReclamationStatus.resolue:
      case ReclamationStatus.rejetee:
        // Seule une réouverture est possible.
        return {ReclamationStatus.enCours};
    }
  }
}

enum ReclamationPriorite {
  basse,
  normale,
  haute,
  urgente;

  String get label {
    switch (this) {
      case ReclamationPriorite.basse:
        return 'Basse';
      case ReclamationPriorite.normale:
        return 'Normale';
      case ReclamationPriorite.haute:
        return 'Haute';
      case ReclamationPriorite.urgente:
        return 'Urgente';
    }
  }

  /// Délai maximal de traitement (SLA) selon la priorité.
  Duration get sla {
    switch (this) {
      case ReclamationPriorite.basse:
        return const Duration(hours: 120);
      case ReclamationPriorite.normale:
        return const Duration(hours: 72);
      case ReclamationPriorite.haute:
        return const Duration(hours: 24);
      case ReclamationPriorite.urgente:
        return const Duration(hours: 6);
    }
  }

  Color get couleur {
    switch (this) {
      case ReclamationPriorite.basse:
        return const Color(0xFF6C7A89);
      case ReclamationPriorite.normale:
        return const Color(0xFF0057B8);
      case ReclamationPriorite.haute:
        return const Color(0xFFE5881D);
      case ReclamationPriorite.urgente:
        return const Color(0xFFC62828);
    }
  }

  static ReclamationPriorite? depuisLibelle(String? valeur) {
    final v = (valeur ?? '').trim().toLowerCase();
    for (final p in ReclamationPriorite.values) {
      if (p.name == v || p.label.toLowerCase() == v) return p;
    }
    return null;
  }
}

/// Message échangé dans le fil d'une réclamation (admin ou étudiant).
class ReclamationResponse {
  final String message;
  final DateTime date;
  final String? audioPath; // URL ou chemin vocal
  final String? imagePath; // URL ou chemin image
  final bool parAdmin;
  final String? auteurNom;

  const ReclamationResponse({
    required this.message,
    required this.date,
    this.audioPath,
    this.imagePath,
    this.parAdmin = true,
    this.auteurNom,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'date': date.toIso8601String(),
    'audioPath': audioPath,
    'imagePath': imagePath,
    'parAdmin': parAdmin,
    'auteurNom': auteurNom,
  };

  factory ReclamationResponse.fromJson(Map json) => ReclamationResponse(
    message: json['message'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    audioPath: json['audioPath'] as String?,
    imagePath: json['imagePath'] as String?,
    parAdmin: json['parAdmin'] as bool? ?? true,
    auteurNom: json['auteurNom'] as String?,
  );
}

/// Entrée de l'historique (traçabilité / audit).
class ReclamationEvenement {
  final DateTime date;
  final String libelle;
  final String? auteur;

  const ReclamationEvenement({
    required this.date,
    required this.libelle,
    this.auteur,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'libelle': libelle,
    'auteur': auteur,
  };

  factory ReclamationEvenement.fromJson(Map json) => ReclamationEvenement(
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    libelle: json['libelle'] as String? ?? '',
    auteur: json['auteur'] as String?,
  );
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

  // --- Métier avancé (stocké dans la colonne `meta`) ---
  final ReclamationPriorite priorite;
  final String? auteurId;
  final String? auteurNom;
  final String? sentiment;
  final int? satisfaction; // note 1..5 après résolution
  final String? commentaireSatisfaction;
  final int nombreReouvertures;
  final DateTime? dateCloture;
  final List<ReclamationEvenement> historique;

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
    this.priorite = ReclamationPriorite.normale,
    this.auteurId,
    this.auteurNom,
    this.sentiment,
    this.satisfaction,
    this.commentaireSatisfaction,
    this.nombreReouvertures = 0,
    this.dateCloture,
    this.historique = const [],
  });

  static const _absent = Object();

  Reclamation copyWith({
    ReclamationType? type,
    String? sujet,
    String? description,
    String? trajet,
    ReclamationStatus? status,
    Object? autreCategorie = _absent,
    Object? aiConseil = _absent,
    List<ReclamationResponse>? responses,
    ReclamationPriorite? priorite,
    Object? sentiment = _absent,
    Object? satisfaction = _absent,
    Object? commentaireSatisfaction = _absent,
    int? nombreReouvertures,
    Object? dateCloture = _absent,
    List<ReclamationEvenement>? historique,
  }) {
    return Reclamation(
      id: id,
      type: type ?? this.type,
      sujet: sujet ?? this.sujet,
      description: description ?? this.description,
      trajet: trajet ?? this.trajet,
      date: date,
      status: status ?? this.status,
      autreCategorie: identical(autreCategorie, _absent)
          ? this.autreCategorie
          : autreCategorie as String?,
      imagePath: imagePath,
      audioPath: audioPath,
      aiConseil: identical(aiConseil, _absent)
          ? this.aiConseil
          : aiConseil as String?,
      responses: responses ?? this.responses,
      priorite: priorite ?? this.priorite,
      auteurId: auteurId,
      auteurNom: auteurNom,
      sentiment: identical(sentiment, _absent)
          ? this.sentiment
          : sentiment as String?,
      satisfaction: identical(satisfaction, _absent)
          ? this.satisfaction
          : satisfaction as int?,
      commentaireSatisfaction: identical(commentaireSatisfaction, _absent)
          ? this.commentaireSatisfaction
          : commentaireSatisfaction as String?,
      nombreReouvertures: nombreReouvertures ?? this.nombreReouvertures,
      dateCloture: identical(dateCloture, _absent)
          ? this.dateCloture
          : dateCloture as DateTime?,
      historique: historique ?? this.historique,
    );
  }

  String get typeLabel {
    if (type == ReclamationType.autre &&
        autreCategorie != null &&
        autreCategorie!.trim().isNotEmpty) {
      return autreCategorie!.trim();
    }
    return type.label;
  }

  String get statusLabel => status.label;

  /// Date limite de traitement selon le SLA de la priorité.
  DateTime get echeance => date.add(priorite.sla);

  /// SLA dépassé alors que la réclamation n'est pas clôturée.
  bool get estEnRetard =>
      !status.estCloturee && DateTime.now().isAfter(echeance);

  Duration get tempsRestant => echeance.difference(DateTime.now());

  bool get aReponseAdmin => responses.any((r) => r.parAdmin);

  DateTime get derniereActivite {
    var d = date;
    for (final r in responses) {
      if (r.date.isAfter(d)) d = r.date;
    }
    for (final e in historique) {
      if (e.date.isAfter(d)) d = e.date;
    }
    return d;
  }

  /// Délai de première réponse de l'administration.
  Duration? get delaiPremiereReponse {
    final admin = responses.where((r) => r.parAdmin).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (admin.isEmpty) return null;
    return admin.first.date.difference(date);
  }

  Duration? get delaiResolution =>
      status == ReclamationStatus.resolue && dateCloture != null
      ? dateCloture!.difference(date)
      : null;

  Map<String, dynamic> metaToJson() => {
    'priorite': priorite.name,
    'auteurId': auteurId,
    'auteurNom': auteurNom,
    'sentiment': sentiment,
    'satisfaction': satisfaction,
    'commentaireSatisfaction': commentaireSatisfaction,
    'nombreReouvertures': nombreReouvertures,
    'dateCloture': dateCloture?.toIso8601String(),
    'historique': historique.map((e) => e.toJson()).toList(),
  };
}
