import '../services/contexte_utilisateur.dart';

// ============================================================
// MODELE MESSAGE
// ============================================================

enum TypeMessage {
  texte,
  vocal,
  systeme,
}

String formaterDureeVocale(int secondes) {
  final minutes = secondes ~/ 60;
  final reste = secondes % 60;
  return '$minutes:${reste.toString().padLeft(2, '0')}';
}

enum StatutMessage {
  envoye,
  livre,
  lu,
}

class _Undefined {
  const _Undefined();
}

class Message {
  final String id;
  final String? conversationId;
  final String expediteurId;
  final String expediteurNom;
  final String contenu;
  final DateTime dateEnvoi;
  final TypeMessage type;
  final StatutMessage statut;

  final int signalements;
  final bool masque;
  final int? dureeSecondes;
  final String? cheminAudio;
  final bool ecoute;
  final bool supprimePourTous;
  final bool supprimePourMoi;
  final DateTime? dateSuppression;

  const Message({
    required this.id,
    this.conversationId,
    required this.expediteurId,
    required this.expediteurNom,
    required this.contenu,
    required this.dateEnvoi,
    required this.type,
    required this.statut,
    this.signalements = 0,
    this.masque = false,
    this.dureeSecondes,
    this.cheminAudio,
    this.ecoute = false,
    this.supprimePourTous = false,
    this.supprimePourMoi = false,
    this.dateSuppression,
  });

  Message copyWith({
    StatutMessage? statut,
    int? signalements,
    bool? masque,
    int? dureeSecondes,
    String? cheminAudio,
    bool? ecoute,
    bool? supprimePourTous,
    bool? supprimePourMoi,
    DateTime? dateSuppression,
    Object? contenu = const _Undefined(),
    Object? conversationId = const _Undefined(),
    Object? expediteurId = const _Undefined(),
    Object? expediteurNom = const _Undefined(),
    Object? id = const _Undefined(),
    Object? dateEnvoi = const _Undefined(),
    Object? type = const _Undefined(),
  }) {
    return Message(
      id: id == const _Undefined() ? this.id : id as String,
      conversationId: conversationId == const _Undefined()
          ? this.conversationId
          : conversationId as String?,
      expediteurId: expediteurId == const _Undefined()
          ? this.expediteurId
          : expediteurId as String,
      expediteurNom: expediteurNom == const _Undefined()
          ? this.expediteurNom
          : expediteurNom as String,
      contenu: contenu == const _Undefined() ? this.contenu : contenu as String,
      dateEnvoi: dateEnvoi == const _Undefined()
          ? this.dateEnvoi
          : dateEnvoi as DateTime,
      type: type == const _Undefined() ? this.type : type as TypeMessage,
      statut: statut ?? this.statut,
      signalements: signalements ?? this.signalements,
      masque: masque ?? this.masque,
      dureeSecondes: dureeSecondes ?? this.dureeSecondes,
      cheminAudio: cheminAudio ?? this.cheminAudio,
      ecoute: ecoute ?? this.ecoute,
      supprimePourTous: supprimePourTous ?? this.supprimePourTous,
      supprimePourMoi: supprimePourMoi ?? this.supprimePourMoi,
      dateSuppression: dateSuppression ?? this.dateSuppression,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'expediteur_id': expediteurId,
      'expediteur_nom': expediteurNom,
      'contenu': contenu,
      'type': type.name,
      'statut': statut.name,
      'duree_secondes': dureeSecondes,
      'chemin_audio': cheminAudio,
      'ecoute': ecoute ? 1 : 0,
      'signale': signalements > 0 ? 1 : 0,
      'masque': masque ? 1 : 0,
      'supprime_pour_tous': supprimePourTous ? 1 : 0,
      'supprime_pour_moi': supprimePourMoi ? 1 : 0,
      'date_envoi': dateEnvoi.toIso8601String(),
      'date_suppression': dateSuppression?.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'].toString(),
      conversationId: map['conversation_id']?.toString(),
      expediteurId: map['expediteur_id'].toString(),
      expediteurNom: map['expediteur_nom']?.toString() ?? '',
      contenu: map['contenu']?.toString() ?? '',
      dateEnvoi: DateTime.parse(map['date_envoi'].toString()),
      type: _typeFromString(map['type']?.toString()),
      statut: _statutFromString(map['statut']?.toString()),
      signalements: (map['signale'] == 1 || map['signalements'] == 1) ? 1 : 0,
      masque: map['masque'] == 1,
      dureeSecondes: map['duree_secondes'] as int?,
      cheminAudio: map['chemin_audio']?.toString(),
      ecoute: map['ecoute'] == 1,
      supprimePourTous: map['supprime_pour_tous'] == 1,
      supprimePourMoi: map['supprime_pour_moi'] == 1,
      dateSuppression: map['date_suppression'] != null
          ? DateTime.parse(map['date_suppression'].toString())
          : null,
    );
  }

  static TypeMessage _typeFromString(String? s) {
    switch (s) {
      case 'vocal':
        return TypeMessage.vocal;
      case 'systeme':
        return TypeMessage.systeme;
      default:
        return TypeMessage.texte;
    }
  }

  static StatutMessage _statutFromString(String? s) {
    switch (s) {
      case 'livre':
        return StatutMessage.livre;
      case 'lu':
        return StatutMessage.lu;
      default:
        return StatutMessage.envoye;
    }
  }

  bool get estSignale => signalements > 0;
  bool get estMien => expediteurId == ContexteUtilisateur.instance.idConnecte;
  bool get estSysteme => type == TypeMessage.systeme;
  bool get estVocal => type == TypeMessage.vocal;
  String get dureeVocalFormatee => formaterDureeVocale(dureeSecondes ?? 0);
}

