// ============================================================
// MODELE CONVERSATION
// ============================================================

import 'membre.dart';

/// Type de conversation : privé (1 à 1) ou groupe de trajet.
enum TypeConversation {
  prive,
  groupe,
}

class Conversation {
  final String id;
  final TypeConversation type;
  final String titre;
  final String trajetLabel;
  final List<Membre> membres;
  final String dernierMessage;
  final DateTime dateDernierMessage;
  final int nonLus;
  final bool muet;

  /// Trajet associé (uniquement pour les groupes).
  final String? trajetId;

  /// Créateur du groupe (conducteur du trajet).
  final String createurId;

  /// Date de création (colonne `created_at`).
  final DateTime? dateCreation;

  /// Groupe archivé : lecture seule.
  final bool archive;

  /// Utilisateur bloqué (conversations privées uniquement).
  final bool bloque;

  const Conversation({
    required this.id,
    required this.type,
    required this.titre,
    required this.trajetLabel,
    required this.membres,
    required this.dernierMessage,
    required this.dateDernierMessage,
    required this.nonLus,
    required this.muet,
    required this.createurId,
    this.trajetId,
    this.dateCreation,
    this.archive = false,
    this.bloque = false,
  });

  /// Copie de la conversation avec les champs fournis remplacés.
  Conversation copyWith({
    String? titre,
    String? trajetLabel,
    List<Membre>? membres,
    String? dernierMessage,
    DateTime? dateDernierMessage,
    int? nonLus,
    bool? muet,
    String? trajetId,
    String? createurId,
    DateTime? dateCreation,
    bool? archive,
    bool? bloque,
  }) {
    return Conversation(
      id: id,
      type: type,
      titre: titre ?? this.titre,
      trajetLabel: trajetLabel ?? this.trajetLabel,
      membres: membres ?? this.membres,
      dernierMessage: dernierMessage ?? this.dernierMessage,
      dateDernierMessage:
          dateDernierMessage ?? this.dateDernierMessage,
      nonLus: nonLus ?? this.nonLus,
      muet: muet ?? this.muet,
      trajetId: trajetId ?? this.trajetId,
      createurId: createurId ?? this.createurId,
      dateCreation: dateCreation ?? this.dateCreation,
      archive: archive ?? this.archive,
      bloque: bloque ?? this.bloque,
    );
  }

  /// Ligne de la table `msg_conversation`.
  ///
  /// `membres`, `nonLus`, `dernierMessage` et `dateDernierMessage`
  /// ne sont pas stockés : les membres vivent dans `msg_membre`
  /// et le reste est calculé à partir des messages.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'titre': titre,
      'trajet_id': trajetId,
      'trajet_label': trajetLabel,
      'createur_id': createurId,
      'archivee': archive ? 1 : 0,
      'muet': muet ? 1 : 0,
      'created_at':
          (dateCreation ?? dateDernierMessage).toIso8601String(),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    final dateCreation =
        DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return Conversation(
      id: map['id'].toString(),
      type: map['type']?.toString() == TypeConversation.groupe.name
          ? TypeConversation.groupe
          : TypeConversation.prive,
      titre: map['titre']?.toString() ?? '',
      trajetLabel: map['trajet_label']?.toString() ?? '',
      membres: const [],
      dernierMessage: '',
      dateDernierMessage: dateCreation,
      nonLus: 0,
      muet: map['muet'] == 1,
      trajetId: map['trajet_id']?.toString(),
      createurId: map['createur_id']?.toString() ?? '',
      dateCreation: dateCreation,
      archive: map['archivee'] == 1,
    );
  }

  /// Vrai s'il s'agit d'un groupe de trajet.
  bool get estGroupe => type == TypeConversation.groupe;

  /// Identifiants des membres (pratique pour les vérifications).
  List<String> get membresIds =>
      membres.map((membre) => membre.id).toList();

  /// Membre correspondant à un identifiant, ou null.
  Membre? membreParId(String membreId) {
    for (final membre in membres) {
      if (membre.id == membreId) return membre;
    }
    return null;
  }

  /// Initiale affichée dans l'avatar (pas de couleur dédiée :
  /// l'avatar utilise toujours AppColors.primaire).
  String get initiale {
    if (titre.isEmpty) return '?';
    return titre.trim()[0].toUpperCase();
  }
}
