// ============================================================
// DONNÉES PROVISOIRES DE LA MESSAGERIE
// ============================================================
//
// Les conversations et les messages vivent désormais dans SQLite.
// Les trajets sont fournis par le module Trajets (TrajetService).
// Seules les réservations restent provisoires en attendant leur
// branchement sur le module Réservations.
//
// Les réservations sont vérifiées contre les utilisateurs réellement
// inscrits (table `app_users`) : un passager qui n'existe pas n'est
// jamais proposé.

class Reservation {
  final String id;
  final String trajetId;
  final String passagerId;
  final bool confirmee;

  const Reservation({
    required this.id,
    required this.trajetId,
    required this.passagerId,
    required this.confirmee,
  });

  Reservation copyWith({bool? confirmee}) {
    return Reservation(
      id: id,
      trajetId: trajetId,
      passagerId: passagerId,
      confirmee: confirmee ?? this.confirmee,
    );
  }
}

/// Le nom du passager est toujours lu dans `app_users` : les entrées
/// dont l'identifiant n'existe pas sont ignorées.
final List<Reservation> reservationsProvisoires = [
  const Reservation(
    id: '1',
    trajetId: '1',
    passagerId: 'usr_yassine',
    confirmee: true,
  ),
  const Reservation(
    id: '2',
    trajetId: '1',
    passagerId: 'usr_sana',
    confirmee: true,
  ),
  const Reservation(
    id: '3',
    trajetId: '1',
    passagerId: 'usr_karim',
    confirmee: true,
  ),
  const Reservation(
    id: '4',
    trajetId: '1',
    passagerId: 'usr_ahmed',
    confirmee: true,
  ),
  const Reservation(
    id: '6',
    trajetId: '2',
    passagerId: 'usr_sana',
    confirmee: true,
  ),
  const Reservation(
    id: '7',
    trajetId: '3',
    passagerId: 'usr_ahmed',
    confirmee: true,
  ),
  const Reservation(
    id: '8',
    trajetId: '3',
    passagerId: 'usr_nour',
    confirmee: false,
  ),
  const Reservation(
    id: '9',
    trajetId: '4',
    passagerId: 'usr_yassine',
    confirmee: true,
  ),
  const Reservation(
    id: '10',
    trajetId: '4',
    passagerId: 'usr_karim',
    confirmee: true,
  ),
];
