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

  /// Nombre de signalements reçus (anti-abus).
  final int signalements;

  /// Vrai si le message a été masqué par le filtre anti-abus.
  final bool masque;

  const Message({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    required this.contenu,
    required this.dateEnvoi,
    required this.type,
    required this.statut,
    this.signalements = 0,
    this.masque = false,
  });

  /// Copie du message avec les champs fournis remplacés.
  Message copyWith({
    StatutMessage? statut,
    int? signalements,
    bool? masque,
  }) {
    return Message(
      id: id,
      expediteurId: expediteurId,
      expediteurNom: expediteurNom,
      contenu: contenu,
      dateEnvoi: dateEnvoi,
      type: type,
      statut: statut ?? this.statut,
      signalements: signalements ?? this.signalements,
      masque: masque ?? this.masque,
    );
  }

  /// Vrai si le message a déjà été signalé.
  bool get estSignale => signalements > 0;

  /// Le message m'appartient si je suis l'expéditeur.
  bool get estMien => expediteurId == monId;

  /// Message système (affiché centré, sans bulle).
  bool get estSysteme => type == TypeMessage.systeme;
}
