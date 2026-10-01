class Trajet {
  final int id;
  final int conducteurId;
  final String villeDepart;
  final String villeArrivee;
  final DateTime dateDepart;
  final String vehicule;
  final int placesTotales;
  final int placesDispo;

  Trajet({
    required this.id,
    required this.conducteurId,
    required this.villeDepart,
    required this.villeArrivee,
    required this.dateDepart,
    required this.vehicule,
    required this.placesTotales,
    required this.placesDispo,
  });
}