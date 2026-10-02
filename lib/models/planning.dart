// lib/models/planning.dart

class Planning {
  final int? id;
  final String lieuDepart;
  final String destination;
  final String date; // Format: "2026-10-05" ou "Lun. 5 oct."
  final String heure; // Format: "07:30"
  final String statut; // "À venir", "Terminé", "Annulé"
  final bool rappelActif;
  final int rappelDelai; // en minutes (ex: 30)
  final String role; // "Conducteur" ou "Passager"
  final int placesDisponibles; // Optionnel

  Planning({
    this.id,
    required this.lieuDepart,
    required this.destination,
    required this.date,
    required this.heure,
    this.statut = 'À venir',
    this.rappelActif = true,
    this.rappelDelai = 30,
    this.role = 'Conducteur',
    this.placesDisponibles = 0,
  });

  // Convertir en Map pour Sqflite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lieuDepart': lieuDepart,
      'destination': destination,
      'date': date,
      'heure': heure,
      'statut': statut,
      'rappelActif': rappelActif ? 1 : 0,
      'rappelDelai': rappelDelai,
      'role': role,
      'placesDisponibles': placesDisponibles,
    };
  }

  // Créer un objet depuis une Map Sqflite
  factory Planning.fromMap(Map<String, dynamic> map) {
    return Planning(
      id: map['id'],
      lieuDepart: map['lieuDepart'],
      destination: map['destination'],
      date: map['date'],
      heure: map['heure'],
      statut: map['statut'],
      rappelActif: map['rappelActif'] == 1,
      rappelDelai: map['rappelDelai'],
      role: map['role'],
      placesDisponibles: map['placesDisponibles'],
    );
  }
}