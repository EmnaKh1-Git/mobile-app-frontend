// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/models/lieu.dart
//  Un lieu choisi par recherche ou sur la carte (départ / arrivée).
//  Enregistré dans SQLite (table « lieux ») pour les onglets
//  « Suggéré » (lieux récents) et « Enregistré » (favoris).
// ============================================================

import '../core/utils/geo.dart';

class Lieu {
  /// id SQLite (null tant que le lieu n'a pas été mémorisé)
  final int? id;

  /// Nom principal : « Rue d'Istanbul », « Clinique Les Jasmins »
  final String nom;

  /// Complément affiché en gris : « Cité Az-Zouhour, Tunis »
  final String adresse;

  /// Ville seule (utilisée par la recherche de trajets et les cartes de trajet)
  final String ville;

  final double lat;
  final double lng;

  /// Favori (onglet « Enregistré »)
  final bool enregistre;

  const Lieu({
    this.id,
    required this.nom,
    this.adresse = '',
    this.ville = '',
    required this.lat,
    required this.lng,
    this.enregistre = false,
  });

  /// Ville si elle est connue, sinon le nom du lieu
  String get villeOuNom => ville.trim().isNotEmpty ? ville.trim() : nom;

  /// « Rue d'Istanbul, El Mourouj » (ou juste « Sousse »)
  String get libelleCourt =>
      ville.isEmpty || ville == nom ? nom : '$nom, $ville';

  /// Distance à vol d'oiseau (km) vers un autre lieu
  double distanceVers(Lieu autre) => distanceEntre(lat, lng, autre.lat, autre.lng);

  /// Même endroit (à ~50 m près) et même nom
  bool estLeMemeQue(Lieu autre) =>
      nom == autre.nom &&
      (lat - autre.lat).abs() < 0.0005 &&
      (lng - autre.lng).abs() < 0.0005;

  Lieu copyWith({int? id, bool? enregistre}) => Lieu(
        id: id ?? this.id,
        nom: nom,
        adresse: adresse,
        ville: ville,
        lat: lat,
        lng: lng,
        enregistre: enregistre ?? this.enregistre,
      );

  // ---------- SQLite (table « lieux ») ----------
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'adresse': adresse,
        'ville': ville,
        'lat': lat,
        'lng': lng,
        'enregistre': enregistre ? 1 : 0,
        'date_utilisation': DateTime.now().toIso8601String(),
      };

  factory Lieu.fromMap(Map<String, dynamic> m) => Lieu(
        id: m['id'] as int?,
        nom: (m['nom'] as String?) ?? '',
        adresse: (m['adresse'] as String?) ?? '',
        ville: (m['ville'] as String?) ?? '',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        enregistre: (m['enregistre'] as int? ?? 0) == 1,
      );
}
