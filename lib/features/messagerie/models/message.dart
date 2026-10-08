import '../../../core/constants/app_constants.dart';

// ============================================================
// MODELE MESSAGE
// ============================================================

/// Type de message : texte normal ou message système
/// (ex. « Mariem a rejoint la conversation »).
enum TypeMessage {
  texte,
  systeme,
}

/// État d'envoi d'un message.
enum StatutMessage {
  envoye,
  livre,
  lu,
}

class Message {
  final int id;
  final int expediteurId;
  final String expediteurNom;
  final String contenu;
  final DateTime dateEnvoi;
  final TypeMessage type;
  final StatutMessage statut;

  const Message({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    required this.contenu,
    required this.dateEnvoi,
    required this.type,
    required this.statut,
  });

  /// Le message m'appartient si je suis l'expéditeur.
  bool get estMien => expediteurId == monId;

  /// Message système (affiché centré, sans bulle).
  bool get estSysteme => type == TypeMessage.systeme;
}
