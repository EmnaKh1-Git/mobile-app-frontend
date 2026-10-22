class Planning {
  final int? id;
  final String lieuDepart;
  final double? lieuDepartLat; // AJOUTER
  final double? lieuDepartLng; // AJOUTER
  final String destination;
  final double? destinationLat; // AJOUTER
  final double? destinationLng; // AJOUTER
  final String date;
  final String heure;
  final String statut;
  final bool rappelActif;
  final int rappelDelai;
  final String role;
  final int placesDisponibles;

  Planning({
    this.id,
    required this.lieuDepart,
    this.lieuDepartLat, // AJOUTER
    this.lieuDepartLng, // AJOUTER
    required this.destination,
    this.destinationLat, // AJOUTER
    this.destinationLng, // AJOUTER
    required this.date,
    required this.heure,
    this.statut = 'À venir',
    this.rappelActif = true,
    this.rappelDelai = 30,
    this.role = 'Conducteur',
    this.placesDisponibles = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lieuDepart': lieuDepart,
      'lieuDepartLat': lieuDepartLat, // AJOUTER
      'lieuDepartLng': lieuDepartLng, // AJOUTER
      'destination': destination,
      'destinationLat': destinationLat, // AJOUTER
      'destinationLng': destinationLng, // AJOUTER
      'date': date,
      'heure': heure,
      'statut': statut,
      'rappelActif': rappelActif ? 1 : 0,
      'rappelDelai': rappelDelai,
      'role': role,
      'placesDisponibles': placesDisponibles,
    };
  }

  factory Planning.fromMap(Map<String, dynamic> map) {
    return Planning(
      id: map['id'],
      lieuDepart: map['lieuDepart'],
      lieuDepartLat: map['lieuDepartLat']?.toDouble(), // AJOUTER
      lieuDepartLng: map['lieuDepartLng']?.toDouble(), // AJOUTER
      destination: map['destination'],
      destinationLat: map['destinationLat']?.toDouble(), // AJOUTER
      destinationLng: map['destinationLng']?.toDouble(), // AJOUTER
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