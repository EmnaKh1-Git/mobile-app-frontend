import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';

import '../models/conversation.dart';
import '../models/message.dart';

// ============================================================
// DONNEES FACTICES DE LA MESSAGERIE
// (aucune base de données, aucune API : tout est en dur ici)
// ============================================================

/// Identifiants des autres utilisateurs (moi = monId).
const int yassineId = 2;
const int mariemId = 3;
const int ahmedId = 4;
const int sanaId = 5;
const int karimId = 6;

/// Les 5 conversations factices : 3 privées + 2 groupes de trajet.
final List<Conversation> conversationsMock = [
  // --------------------------------------------------------
  // CONVERSATION 1 — privée (non lue)
  // --------------------------------------------------------
  Conversation(
    id: 1,
    type: TypeConversation.prive,
    titre: 'Yassine Ben Salah',
    trajetLabel: 'Tunis → Hammamet',
    membres: const ['Yassine Ben Salah'],
    dernierMessage: 'Je serai à la station à 14h30 👍',
    dateDernierMessage: DateTime(2026, 10, 8, 9, 42),
    nonLus: 2,
    muet: false,
  ),

  // --------------------------------------------------------
  // CONVERSATION 2 — privée (muet)
  // --------------------------------------------------------
  Conversation(
    id: 2,
    type: TypeConversation.prive,
    titre: 'Mariem Trabelsi',
    trajetLabel: 'Tunis → Sousse',
    membres: const ['Mariem Trabelsi'],
    dernierMessage: 'Merci pour le covoiturage !',
    dateDernierMessage: DateTime(2026, 10, 7, 18, 5),
    nonLus: 0,
    muet: true,
  ),

  // --------------------------------------------------------
  // CONVERSATION 3 — privée (non lue)
  // --------------------------------------------------------
  Conversation(
    id: 3,
    type: TypeConversation.prive,
    titre: 'Ahmed Gharbi',
    trajetLabel: 'Tunis → Nabeul',
    membres: const ['Ahmed Gharbi'],
    dernierMessage: 'On part vendredi matin ?',
    dateDernierMessage: DateTime(2026, 10, 6, 20, 15),
    nonLus: 1,
    muet: false,
  ),

  // --------------------------------------------------------
  // CONVERSATION 4 — groupe de trajet (non lu)
  // --------------------------------------------------------
  Conversation(
    id: 4,
    type: TypeConversation.groupe,
    titre: 'Groupe Tunis → Hammamet',
    trajetLabel: 'Tunis → Hammamet · 12/10/2026',
    membres: const [
      monNom,
      'Yassine Ben Salah',
      'Sana Mahdi',
      'Karim Jlassi',
      'Ahmed Gharbi',
    ],
    dernierMessage: 'Karim : j\'apporte 2 bouteilles d\'eau',
    dateDernierMessage: DateTime(2026, 10, 8, 8, 20),
    nonLus: 3,
    muet: false,
    trajetId: 1,
  ),

  // --------------------------------------------------------
  // CONVERSATION 5 — groupe de trajet
  // --------------------------------------------------------
  Conversation(
    id: 5,
    type: TypeConversation.groupe,
    titre: 'Groupe Tunis → Sousse',
    trajetLabel: 'Tunis → Sousse · 18/10/2026',
    membres: const [
      'Mariem Trabelsi',
      monNom,
      'Sana Mahdi',
    ],
    dernierMessage: 'Mariem : parfait, à samedi !',
    dateDernierMessage: DateTime(2026, 10, 5, 16, 48),
    nonLus: 0,
    muet: false,
    trajetId: 2,
  ),
];

/// Messages factices classés par identifiant de conversation.
final Map<int, List<Message>> messagesMock = {
  // --------------------------------------------------------
  // CONVERSATION 1 — Yassine (8 messages)
  // --------------------------------------------------------
  1: [
    Message(
      id: 101,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Salut Yassine, tu proposes encore le trajet '
          'Tunis → Hammamet demain ?',
      dateEnvoi: DateTime(2026, 10, 7, 17, 30),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 102,
      expediteurId: yassineId,
      expediteurNom: 'Yassine Ben Salah',
      contenu: 'Oui tout à fait ! Je passe à 14h00 '
          'près de la faculté.',
      dateEnvoi: DateTime(2026, 10, 7, 17, 35),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 103,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Parfait, je réserve une place.',
      dateEnvoi: DateTime(2026, 10, 7, 17, 38),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 104,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Vous avez réservé une place dans le trajet '
          'Tunis → Hammamet.',
      dateEnvoi: DateTime(2026, 10, 7, 17, 39),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 105,
      expediteurId: yassineId,
      expediteurNom: 'Yassine Ben Salah',
      contenu: 'Bien reçu, à demain alors.',
      dateEnvoi: DateTime(2026, 10, 7, 17, 45),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 106,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Tu as une place pour un bagage ?',
      dateEnvoi: DateTime(2026, 10, 8, 9, 20),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 107,
      expediteurId: yassineId,
      expediteurNom: 'Yassine Ben Salah',
      contenu: 'Oui, le coffre est vide.',
      dateEnvoi: DateTime(2026, 10, 8, 9, 35),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
    Message(
      id: 108,
      expediteurId: yassineId,
      expediteurNom: 'Yassine Ben Salah',
      contenu: 'Je serai à la station à 14h30 👍',
      dateEnvoi: DateTime(2026, 10, 8, 9, 42),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
  ],

  // --------------------------------------------------------
  // CONVERSATION 2 — Mariem (6 messages)
  // --------------------------------------------------------
  2: [
    Message(
      id: 201,
      expediteurId: mariemId,
      expediteurNom: 'Mariem Trabelsi',
      contenu: 'Bonjour, il te reste une place '
          'pour Sousse ?',
      dateEnvoi: DateTime(2026, 10, 6, 11, 2),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 202,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Bonjour ! Oui, il reste 1 place.',
      dateEnvoi: DateTime(2026, 10, 6, 11, 10),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 203,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Mariem Trabelsi a rejoint la conversation.',
      dateEnvoi: DateTime(2026, 10, 6, 11, 11),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 204,
      expediteurId: mariemId,
      expediteurNom: 'Mariem Trabelsi',
      contenu: 'Super, on part à quelle heure ?',
      dateEnvoi: DateTime(2026, 10, 6, 11, 15),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 205,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Départ à 8h00 devant la résidence.',
      dateEnvoi: DateTime(2026, 10, 6, 11, 20),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 206,
      expediteurId: mariemId,
      expediteurNom: 'Mariem Trabelsi',
      contenu: 'Merci pour le covoiturage !',
      dateEnvoi: DateTime(2026, 10, 7, 18, 5),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
  ],

  // --------------------------------------------------------
  // CONVERSATION 3 — Ahmed (5 messages)
  // --------------------------------------------------------
  3: [
    Message(
      id: 301,
      expediteurId: ahmedId,
      expediteurNom: 'Ahmed Gharbi',
      contenu: 'Salut $monNom, tu vas vers Nabeul '
          'cette semaine ?',
      dateEnvoi: DateTime(2026, 10, 5, 14, 0),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 302,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Oui, je pars jeudi en fin de journée.',
      dateEnvoi: DateTime(2026, 10, 5, 14, 25),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 303,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Trajet Tunis → Nabeul publié par '
          'Ahmed Gharbi.',
      dateEnvoi: DateTime(2026, 10, 5, 14, 30),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 304,
      expediteurId: ahmedId,
      expediteurNom: 'Ahmed Gharbi',
      contenu: 'Je passe vers 17h si ça te va.',
      dateEnvoi: DateTime(2026, 10, 6, 19, 50),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
    Message(
      id: 305,
      expediteurId: ahmedId,
      expediteurNom: 'Ahmed Gharbi',
      contenu: 'On part vendredi matin ?',
      dateEnvoi: DateTime(2026, 10, 6, 20, 15),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
  ],

  // --------------------------------------------------------
  // CONVERSATION 4 — Groupe Tunis → Hammamet (9 messages)
  // --------------------------------------------------------
  4: [
    Message(
      id: 401,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Le groupe « Tunis → Hammamet » a été créé '
          'par $monNom.',
      dateEnvoi: DateTime(2026, 10, 6, 9, 0),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 402,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Bonjour à tous ! On confirme le départ '
          'lundi 12 octobre à 9h00.',
      dateEnvoi: DateTime(2026, 10, 6, 9, 5),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 403,
      expediteurId: yassineId,
      expediteurNom: 'Yassine Ben Salah',
      contenu: 'Ça marche pour moi 👍',
      dateEnvoi: DateTime(2026, 10, 6, 9, 12),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 404,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Sana Mahdi a rejoint la conversation.',
      dateEnvoi: DateTime(2026, 10, 6, 10, 3),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 405,
      expediteurId: sanaId,
      expediteurNom: 'Sana Mahdi',
      contenu: 'Bonjour, je peux venir avec une valise ?',
      dateEnvoi: DateTime(2026, 10, 6, 10, 10),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 406,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Pas de problème, le coffre est assez grand.',
      dateEnvoi: DateTime(2026, 10, 6, 10, 15),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 407,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Karim Jlassi a rejoint la conversation.',
      dateEnvoi: DateTime(2026, 10, 7, 8, 40),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 408,
      expediteurId: sanaId,
      expediteurNom: 'Sana Mahdi',
      contenu: 'Quelqu\'un a des cacahuètes pour la route ?',
      dateEnvoi: DateTime(2026, 10, 8, 8, 15),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
    Message(
      id: 409,
      expediteurId: karimId,
      expediteurNom: 'Karim Jlassi',
      contenu: 'j\'apporte 2 bouteilles d\'eau',
      dateEnvoi: DateTime(2026, 10, 8, 8, 20),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    ),
  ],

  // --------------------------------------------------------
  // CONVERSATION 5 — Groupe Tunis → Sousse (7 messages)
  // --------------------------------------------------------
  5: [
    Message(
      id: 501,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Le groupe « Tunis → Sousse » a été créé '
          'par Mariem Trabelsi.',
      dateEnvoi: DateTime(2026, 10, 4, 15, 0),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 502,
      expediteurId: mariemId,
      expediteurNom: 'Mariem Trabelsi',
      contenu: 'On organize le covoiturage de samedi ?',
      dateEnvoi: DateTime(2026, 10, 4, 15, 5),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 503,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Oui, je peux conduire.',
      dateEnvoi: DateTime(2026, 10, 4, 15, 20),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 504,
      expediteurId: 0,
      expediteurNom: 'Système',
      contenu: 'Sana Mahdi a rejoint la conversation.',
      dateEnvoi: DateTime(2026, 10, 4, 16, 0),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 505,
      expediteurId: sanaId,
      expediteurNom: 'Sana Mahdi',
      contenu: 'Je prends 2 places, merci !',
      dateEnvoi: DateTime(2026, 10, 5, 9, 30),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 506,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Départ à 7h30 devant la résidence '
          'universitaire.',
      dateEnvoi: DateTime(2026, 10, 5, 16, 40),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
    Message(
      id: 507,
      expediteurId: mariemId,
      expediteurNom: 'Mariem Trabelsi',
      contenu: 'Parfait, à samedi !',
      dateEnvoi: DateTime(2026, 10, 5, 16, 48),
      type: TypeMessage.texte,
      statut: StatutMessage.lu,
    ),
  ],
};

/// Messages d'une conversation (liste modifiable,
/// l'envoi local ajoutera une bulle via setState).
List<Message> messagesDe(int conversationId) {
  return messagesMock[conversationId] ?? <Message>[];
}

/// Heure courte d'un message (09:42).
String heureMessage(Message message) {
  return fHeure(message.dateEnvoi);
}

/// Date courte d'un message (08/10/2026).
String dateMessage(Message message) {
  return fDateCourte(message.dateEnvoi);
}

// ============================================================
// TRAJETS FACTICES — création et gestion des groupes
// ============================================================

class TrajetPropose {
  final int id;
  final String villeDepart;
  final String villeArrivee;
  final DateTime dateDepart;
  final int placesTotales;
  final int conducteurId;
  final String conducteurNom;
  final bool termine;

  const TrajetPropose({
    required this.id,
    required this.villeDepart,
    required this.villeArrivee,
    required this.dateDepart,
    required this.placesTotales,
    required this.conducteurId,
    required this.conducteurNom,
    this.termine = false,
  });

  String get label => '$villeDepart → $villeArrivee';

  /// Nombre maximal de membres : places du trajet + le conducteur.
  int get capaciteGroupe => placesTotales + 1;

  TrajetPropose copyWith({bool? termine}) {
    return TrajetPropose(
      id: id,
      villeDepart: villeDepart,
      villeArrivee: villeArrivee,
      dateDepart: dateDepart,
      placesTotales: placesTotales,
      conducteurId: conducteurId,
      conducteurNom: conducteurNom,
      termine: termine ?? this.termine,
    );
  }
}

/// Tous les trajets factices (les miens et ceux des autres).
final List<TrajetPropose> trajetsMock = [
  TrajetPropose(
    id: 1,
    villeDepart: 'Tunis',
    villeArrivee: 'Hammamet',
    dateDepart: DateTime(2026, 9, 27, 8, 0),
    placesTotales: 4,
    conducteurId: monId,
    conducteurNom: monNom,
  ),
  TrajetPropose(
    id: 2,
    villeDepart: 'Tunis',
    villeArrivee: 'Sousse',
    dateDepart: DateTime(2026, 9, 30, 9, 30),
    placesTotales: 3,
    conducteurId: mariemId,
    conducteurNom: 'Mariem Trabelsi',
  ),
  TrajetPropose(
    id: 3,
    villeDepart: 'Tunis',
    villeArrivee: 'Nabeul',
    dateDepart: DateTime(2026, 10, 2, 7, 45),
    placesTotales: 4,
    conducteurId: monId,
    conducteurNom: monNom,
  ),
  TrajetPropose(
    id: 4,
    villeDepart: 'Tunis',
    villeArrivee: 'Bizerte',
    dateDepart: DateTime(2026, 10, 5, 8, 15),
    placesTotales: 3,
    conducteurId: monId,
    conducteurNom: monNom,
  ),
];

// ============================================================
// RÉSERVATIONS FACTICES
// ============================================================

class Reservation {
  final int id;
  final int trajetId;
  final int passagerId;
  final String passagerNom;
  final bool confirmee;

  const Reservation({
    required this.id,
    required this.trajetId,
    required this.passagerId,
    required this.passagerNom,
    required this.confirmee,
  });

  Reservation copyWith({bool? confirmee}) {
    return Reservation(
      id: id,
      trajetId: trajetId,
      passagerId: passagerId,
      passagerNom: passagerNom,
      confirmee: confirmee ?? this.confirmee,
    );
  }
}

/// Réservations factices (confirmées et en attente).
final List<Reservation> reservationsMock = [
  Reservation(
    id: 1,
    trajetId: 1,
    passagerId: yassineId,
    passagerNom: 'Yassine Ben Salah',
    confirmee: true,
  ),
  Reservation(
    id: 2,
    trajetId: 1,
    passagerId: sanaId,
    passagerNom: 'Sana Mahdi',
    confirmee: true,
  ),
  Reservation(
    id: 3,
    trajetId: 1,
    passagerId: karimId,
    passagerNom: 'Karim Jlassi',
    confirmee: true,
  ),
  Reservation(
    id: 4,
    trajetId: 1,
    passagerId: ahmedId,
    passagerNom: 'Ahmed Gharbi',
    confirmee: true,
  ),
  Reservation(
    id: 5,
    trajetId: 2,
    passagerId: monId,
    passagerNom: monNom,
    confirmee: true,
  ),
  Reservation(
    id: 6,
    trajetId: 2,
    passagerId: sanaId,
    passagerNom: 'Sana Mahdi',
    confirmee: true,
  ),
  Reservation(
    id: 7,
    trajetId: 3,
    passagerId: ahmedId,
    passagerNom: 'Ahmed Gharbi',
    confirmee: true,
  ),
  Reservation(
    id: 8,
    trajetId: 3,
    passagerId: 7,
    passagerNom: 'Nour Ben Ali',
    confirmee: false,
  ),
  Reservation(
    id: 9,
    trajetId: 4,
    passagerId: yassineId,
    passagerNom: 'Yassine Ben Salah',
    confirmee: true,
  ),
  Reservation(
    id: 10,
    trajetId: 4,
    passagerId: karimId,
    passagerNom: 'Karim Jlassi',
    confirmee: true,
  ),
];


