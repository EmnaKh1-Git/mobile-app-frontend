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
  });

  /// Vrai s'il s'agit d'un groupe de trajet.
  bool get estGroupe => type == TypeConversation.groupe;

  /// Initiale affichée dans l'avatar (pas de couleur dédiée :
  /// l'avatar utilise toujours AppColors.primaire).
  String get initiale {
    if (titre.isEmpty) return '?';
    return titre.trim()[0].toUpperCase();
  }
}
