import '../../../core/constants/app_constants.dart';

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
  final int id;
  final int expediteurId;
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
    Object? expediteurId = const _Undefined(),
    Object? expediteurNom = const _Undefined(),
  }) {
    return Message(
      id: id,
      expediteurId: expediteurId == const _Undefined()
          ? this.expediteurId
          : expediteurId as int,
      expediteurNom: expediteurNom == const _Undefined()
          ? this.expediteurNom
          : expediteurNom as String,
      contenu: contenu == const _Undefined() ? this.contenu : contenu as String,
      dateEnvoi: dateEnvoi,
      type: type,
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

  bool get estSignale => signalements > 0;
  bool get estMien => expediteurId == monId;
  bool get estSysteme => type == TypeMessage.systeme;
  bool get estVocal => type == TypeMessage.vocal;
  String get dureeVocalFormatee => formaterDureeVocale(dureeSecondes ?? 0);
}
