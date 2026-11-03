// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/models/discussion_trajet.dart
//  Contient : PresencePassager, PassagerTrajet, TypeMessageTrajet,
//             MessageTrajet, EvaluationTrajet
//
//  Discussion d'un trajet : le conducteur et ses passagers échangent
//  dans un fil commun qui s'ouvre 2 h avant le départ. Au départ, le
//  conducteur pointe les passagers présents ; après le trajet, chacun
//  note les autres.
//  Enregistré dans SQLite via toMap() / fromMap() (voir
//  core/services/discussion_database.dart).
// ============================================================

// ------------------------------------------------------------
// 1. PASSAGER D'UN TRAJET (une réservation)
// ------------------------------------------------------------

/// Pointage au départ par le conducteur
enum PresencePassager { inconnue, present, absent }

class PassagerTrajet {
  /// id SQLite (null tant que la réservation n'est pas enregistrée)
  final int? id;
  final int trajetId;
  final int passagerId;
  final String nom;
  final int places;
  final DateTime dateReservation;
  final PresencePassager presence;

  PassagerTrajet({
    this.id,
    required this.trajetId,
    required this.passagerId,
    required this.nom,
    required this.places,
    DateTime? dateReservation,
    this.presence = PresencePassager.inconnue,
  }) : dateReservation = dateReservation ?? DateTime.now();

  String get initiale => nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();

  PassagerTrajet copyWith({int? id, int? places, PresencePassager? presence}) =>
      PassagerTrajet(
        id: id ?? this.id,
        trajetId: trajetId,
        passagerId: passagerId,
        nom: nom,
        places: places ?? this.places,
        dateReservation: dateReservation,
        presence: presence ?? this.presence,
      );

  // SQLite : table « passagers_trajet »
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'trajet_id': trajetId,
        'passager_id': passagerId,
        'nom': nom,
        'places': places,
        'date_reservation': dateReservation.toIso8601String(),
        'presence': presence.name,
      };

  factory PassagerTrajet.fromMap(Map<String, dynamic> m) => PassagerTrajet(
        id: m['id'] as int?,
        trajetId: m['trajet_id'] as int,
        passagerId: m['passager_id'] as int,
        nom: (m['nom'] as String?) ?? '',
        places: (m['places'] as int?) ?? 1,
        dateReservation: DateTime.parse(m['date_reservation'] as String),
        presence: PresencePassager.values.firstWhere(
          (p) => p.name == m['presence'],
          orElse: () => PresencePassager.inconnue,
        ),
      );
}

// ------------------------------------------------------------
// 2. MESSAGE DE LA DISCUSSION
//    texte   : message écrit par un participant
//    statut  : statut rapide (« Je suis en route », « 5 min de retard »…)
//    systeme : événement du trajet (ouverture, départ, fin, annulation)
// ------------------------------------------------------------
enum TypeMessageTrajet { texte, statut, systeme }

class MessageTrajet {
  final int? id;
  final int trajetId;

  /// 0 pour un message système
  final int auteurId;
  final String auteurNom;
  final String texte;
  final TypeMessageTrajet type;
  final DateTime date;

  MessageTrajet({
    this.id,
    required this.trajetId,
    required this.auteurId,
    required this.auteurNom,
    required this.texte,
    this.type = TypeMessageTrajet.texte,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  bool get estSysteme => type == TypeMessageTrajet.systeme;

  MessageTrajet copyWith({int? id}) => MessageTrajet(
        id: id ?? this.id,
        trajetId: trajetId,
        auteurId: auteurId,
        auteurNom: auteurNom,
        texte: texte,
        type: type,
        date: date,
      );

  // SQLite : table « messages_trajet »
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'trajet_id': trajetId,
        'auteur_id': auteurId,
        'auteur_nom': auteurNom,
        'texte': texte,
        'type': type.name,
        'date': date.toIso8601String(),
      };

  factory MessageTrajet.fromMap(Map<String, dynamic> m) => MessageTrajet(
        id: m['id'] as int?,
        trajetId: m['trajet_id'] as int,
        auteurId: m['auteur_id'] as int,
        auteurNom: (m['auteur_nom'] as String?) ?? '',
        texte: (m['texte'] as String?) ?? '',
        type: TypeMessageTrajet.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => TypeMessageTrajet.texte,
        ),
        date: DateTime.parse(m['date'] as String),
      );
}

// ------------------------------------------------------------
// 3. ÉVALUATION APRÈS LE TRAJET
//    Le conducteur note chaque passager présent, et chaque passager
//    note le conducteur (1 à 5 étoiles + commentaire facultatif).
// ------------------------------------------------------------
class EvaluationTrajet {
  final int? id;
  final int trajetId;
  final int auteurId;
  final String auteurNom;

  /// Personne notée
  final int cibleId;
  final String cibleNom;

  /// De 1 à 5 étoiles
  final int note;
  final String commentaire;
  final DateTime date;

  EvaluationTrajet({
    this.id,
    required this.trajetId,
    required this.auteurId,
    required this.auteurNom,
    required this.cibleId,
    required this.cibleNom,
    required this.note,
    this.commentaire = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  EvaluationTrajet copyWith({int? id}) => EvaluationTrajet(
        id: id ?? this.id,
        trajetId: trajetId,
        auteurId: auteurId,
        auteurNom: auteurNom,
        cibleId: cibleId,
        cibleNom: cibleNom,
        note: note,
        commentaire: commentaire,
        date: date,
      );

  // SQLite : table « evaluations_trajet »
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'trajet_id': trajetId,
        'auteur_id': auteurId,
        'auteur_nom': auteurNom,
        'cible_id': cibleId,
        'cible_nom': cibleNom,
        'note': note,
        'commentaire': commentaire,
        'date': date.toIso8601String(),
      };

  factory EvaluationTrajet.fromMap(Map<String, dynamic> m) => EvaluationTrajet(
        id: m['id'] as int?,
        trajetId: m['trajet_id'] as int,
        auteurId: m['auteur_id'] as int,
        auteurNom: (m['auteur_nom'] as String?) ?? '',
        cibleId: m['cible_id'] as int,
        cibleNom: (m['cible_nom'] as String?) ?? '',
        note: (m['note'] as int?) ?? 5,
        commentaire: (m['commentaire'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
      );
}
