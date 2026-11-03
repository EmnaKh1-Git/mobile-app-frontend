// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/models/notification_trajet.dart
//  Contient : TypeNotification, NotificationTrajet, AlerteTrajet
//
//  Notifications du centre de notifications (cloche de l'accueil) et
//  alertes de recherche (« prévenez-moi quand un trajet Tunis → Sousse
//  est publié »). Enregistrées dans SQLite via toMap() / fromMap()
//  (voir core/services/complements_database.dart).
// ============================================================

enum TypeNotification {
  reservation,
  annulation,
  discussion,
  depart,
  statut,
  evaluation,
  avis,
  alerte,
}

class NotificationTrajet {
  final int? id;

  /// Identifiant unique de l'événement (« depart:12 ») : une même
  /// notification n'est jamais créée deux fois
  final String cle;
  final TypeNotification type;
  final String titre;
  final String texte;

  /// Trajet concerné (null si la notification ne porte pas sur un trajet)
  final int? trajetId;
  final DateTime date;
  final bool lue;

  NotificationTrajet({
    this.id,
    required this.cle,
    required this.type,
    required this.titre,
    required this.texte,
    this.trajetId,
    DateTime? date,
    this.lue = false,
  }) : date = date ?? DateTime.now();

  NotificationTrajet copyWith({int? id, bool? lue}) => NotificationTrajet(
        id: id ?? this.id,
        cle: cle,
        type: type,
        titre: titre,
        texte: texte,
        trajetId: trajetId,
        date: date,
        lue: lue ?? this.lue,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cle': cle,
        'type': type.name,
        'titre': titre,
        'texte': texte,
        'trajet_id': trajetId,
        'date': date.toIso8601String(),
        'lue': lue ? 1 : 0,
      };

  factory NotificationTrajet.fromMap(Map<String, dynamic> m) =>
      NotificationTrajet(
        id: m['id'] as int?,
        cle: m['cle'] as String,
        type: TypeNotification.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => TypeNotification.statut,
        ),
        titre: m['titre'] as String,
        texte: m['texte'] as String,
        trajetId: m['trajet_id'] as int?,
        date: DateTime.parse(m['date'] as String),
        lue: (m['lue'] as int? ?? 0) == 1,
      );
}

/// Alerte de recherche : l'utilisateur est prévenu dès qu'un trajet
/// correspondant est proposé par un autre conducteur
class AlerteTrajet {
  final int? id;

  /// Ville de départ ('' : n'importe où)
  final String villeDepart;

  /// Ville d'arrivée ('' : toutes destinations)
  final String villeArrivee;

  /// Jour souhaité (null : toutes dates)
  final DateTime? jour;

  /// Heure souhaitée, à 2 h près (« vers 8h »)
  final int? heure;

  /// Moment de la journée (nom d'un MomentJournee de l'assistant :
  /// matin, apresMidi, soir), utilisé si [heure] est null
  final String? moment;
  final int places;
  final DateTime dateCreation;

  AlerteTrajet({
    this.id,
    this.villeDepart = '',
    this.villeArrivee = '',
    this.jour,
    this.heure,
    this.moment,
    this.places = 1,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  /// « Tunis → Sousse »
  String get itineraire =>
      '${villeDepart.isEmpty ? 'Partout' : villeDepart} → '
      '${villeArrivee.isEmpty ? 'toutes destinations' : villeArrivee}';

  AlerteTrajet copyWith({int? id}) => AlerteTrajet(
        id: id ?? this.id,
        villeDepart: villeDepart,
        villeArrivee: villeArrivee,
        jour: jour,
        heure: heure,
        moment: moment,
        places: places,
        dateCreation: dateCreation,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ville_depart': villeDepart,
        'ville_arrivee': villeArrivee,
        'jour': jour?.toIso8601String(),
        'heure': heure,
        'moment': moment,
        'places': places,
        'date_creation': dateCreation.toIso8601String(),
      };

  factory AlerteTrajet.fromMap(Map<String, dynamic> m) => AlerteTrajet(
        id: m['id'] as int?,
        villeDepart: (m['ville_depart'] as String?) ?? '',
        villeArrivee: (m['ville_arrivee'] as String?) ?? '',
        jour: m['jour'] != null ? DateTime.parse(m['jour'] as String) : null,
        heure: m['heure'] as int?,
        moment: m['moment'] as String?,
        places: (m['places'] as int?) ?? 1,
        dateCreation: DateTime.parse(m['date_creation'] as String),
      );
}
