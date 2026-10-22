// ============================================================
// MODELE CONVERSATION
// ============================================================

/// Type de conversation : privé (1 à 1) ou groupe de trajet.
enum TypeConversation {
  prive,
  groupe,
}

class Conversation {
  final int id;
  final TypeConversation type;
  final String titre;
  final String trajetLabel;
  final List<String> membres;
  final String dernierMessage;
  final DateTime dateDernierMessage;
  final int nonLus;
  final bool muet;

  /// Trajet associé (uniquement pour les groupes).
  final int? trajetId;

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
    this.trajetId,
    this.archive = false,
    this.bloque = false,
  });

  /// Copie de la conversation avec les champs fournis remplacés.
  Conversation copyWith({
    String? titre,
    String? trajetLabel,
    List<String>? membres,
    String? dernierMessage,
    DateTime? dateDernierMessage,
    int? nonLus,
    bool? muet,
    int? trajetId,
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
      archive: archive ?? this.archive,
      bloque: bloque ?? this.bloque,
    );
  }

  /// Vrai s'il s'agit d'un groupe de trajet.
  bool get estGroupe => type == TypeConversation.groupe;

  /// Initiale affichée dans l'avatar (pas de couleur dédiée :
  /// l'avatar utilise toujours AppColors.primaire).
  String get initiale {
    if (titre.isEmpty) return '?';
    return titre.trim()[0].toUpperCase();
  }
}
