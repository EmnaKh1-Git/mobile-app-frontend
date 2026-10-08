// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/models/trajet.dart
//  Contient : StatutTrajet, Etape, Trajet
//
//  Les champs d'origine (id, conducteurId, villeDepart, villeArrivee,
//  dateDepart, vehicule, placesTotales, placesDispo) sont conservés
//  avec les mêmes noms et types : la page d'accueil continue de
//  fonctionner sans modification.
//  Enregistré dans SQLite via toMap() / fromMap() (voir
//  core/services/trajet_database.dart).
//  Un trajet pas encore enregistré dans SQLite a id = 0.
// ============================================================

import 'package:flutter/material.dart';

// ------------------------------------------------------------
// 1. STATUT DU TRAJET (cycle de vie)
//    BROUILLON -> PUBLIE -> COMPLET -> EN_COURS -> TERMINE
//                     \------> ANNULE
// ------------------------------------------------------------
enum StatutTrajet { brouillon, publie, complet, enCours, termine, annule }

extension StatutTrajetX on StatutTrajet {
  String get libelle {
    switch (this) {
      case StatutTrajet.brouillon:
        return 'Brouillon';
      case StatutTrajet.publie:
        return 'Publié';
      case StatutTrajet.complet:
        return 'Complet';
      case StatutTrajet.enCours:
        return 'En cours';
      case StatutTrajet.termine:
        return 'Terminé';
      case StatutTrajet.annule:
        return 'Annulé';
    }
  }

  Color get couleur {
    switch (this) {
      case StatutTrajet.brouillon:
        return Colors.grey;
      case StatutTrajet.publie:
        return const Color(0xFF3155D9);
      case StatutTrajet.complet:
        return const Color(0xFFFF7A59);
      case StatutTrajet.enCours:
        return const Color(0xFF2864C7);
      case StatutTrajet.termine:
        return const Color(0xFF5B34B8);
      case StatutTrajet.annule:
        return const Color(0xFFA3281A);
    }
  }

  /// Le trajet est encore actif (affiché dans « À venir »)
  bool get estActif =>
      this != StatutTrajet.termine && this != StatutTrajet.annule;
}

// ------------------------------------------------------------
// 2. ÉTAPE INTERMÉDIAIRE (point de passage)
// ------------------------------------------------------------
class Etape {
  final String ville;
  final int ordre;
  final double prix;

  const Etape({required this.ville, required this.ordre, required this.prix});

  // SQLite : table « etapes » (liée à « trajets » par trajet_id)
  Map<String, dynamic> toMap(int trajetId) => {
        'trajet_id': trajetId,
        'ville': ville,
        'ordre': ordre,
        'prix': prix,
      };

  factory Etape.fromMap(Map<String, dynamic> m) => Etape(
        ville: m['ville'] as String,
        ordre: m['ordre'] as int,
        prix: (m['prix'] as num?)?.toDouble() ?? 0,
      );
}

// ------------------------------------------------------------
// 3. ENTITÉ TRAJET
// ------------------------------------------------------------
class Trajet {
  // ---- Champs d'origine (utilisés par la page d'accueil) ----
  final int id;
  final int conducteurId;
  final String villeDepart;
  final String villeArrivee;
  DateTime dateDepart;
  final String vehicule;
  final int placesTotales;
  int placesDispo;

  // ---- Champs ajoutés par le module Trajets ----
  final String conducteurNom;
  final double conducteurNote;
  final int capaciteVehicule;
  final String adresseDepart;
  final String adresseArrivee;
  final List<Etape> etapes;
  final int dureeMinutes;
  final double distanceKm;
  final double prixPlace;
  final bool bagages;
  final bool fumeur;
  final bool animaux;
  final bool reservationAuto;
  final String description;
  StatutTrajet statut;
  final DateTime dateCreation;

  Trajet({
    required this.id,
    required this.conducteurId,
    required this.villeDepart,
    required this.villeArrivee,
    required this.dateDepart,
    required this.vehicule,
    required this.placesTotales,
    int? placesDispo,
    this.conducteurNom = '',
    this.conducteurNote = 5.0,
    this.capaciteVehicule = 4,
    this.adresseDepart = '',
    this.adresseArrivee = '',
    List<Etape>? etapes,
    this.dureeMinutes = 60,
    this.distanceKm = 0,
    this.prixPlace = 0,
    this.bagages = true,
    this.fumeur = false,
    this.animaux = false,
    this.reservationAuto = false,
    this.description = '',
    this.statut = StatutTrajet.publie,
    DateTime? dateCreation,
  })  : placesDispo = placesDispo ?? placesTotales,
        etapes = etapes ?? const <Etape>[],
        dateCreation = dateCreation ?? DateTime.now();

  // ---- Propriétés calculées ----
  DateTime get dateArrivee => dateDepart.add(Duration(minutes: dureeMinutes));
  bool get estPasse => dateDepart.isBefore(DateTime.now());
  bool get estReservable =>
      statut == StatutTrajet.publie && placesDispo > 0 && !estPasse;
  int get placesReservees => placesTotales - placesDispo;
  String get initialeConducteur =>
      conducteurNom.isNotEmpty ? conducteurNom[0].toUpperCase() : '?';

  // ---- RÈGLES DE GESTION (vérifiées avant publication) ----
  /// Retourne null si le trajet est valide, sinon le message d'erreur.
  String? valider() {
    if (villeDepart.trim().isEmpty) return 'La ville de départ est obligatoire.';
    if (villeArrivee.trim().isEmpty) return "La ville d'arrivée est obligatoire.";
    if (villeDepart.trim().toLowerCase() == villeArrivee.trim().toLowerCase()) {
      return "Les villes de départ et d'arrivée doivent être différentes.";
    }
    if (dateDepart.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      return 'Le départ doit être prévu dans au moins 30 minutes.';
    }
    if (placesTotales < 1) return 'Il faut proposer au moins 1 place.';
    if (placesTotales > capaciteVehicule) {
      return 'Le véhicule ne peut accueillir que $capaciteVehicule passagers.';
    }
    if (prixPlace < 0) return 'Le prix ne peut pas être négatif.';
    if (distanceKm > 0 && prixPlace / distanceKm > 0.5) {
      return 'Le prix dépasse le plafond autorisé (0,5 DT / km).';
    }
    return null;
  }

  /// Copie du trajet en changeant certains champs
  /// (utilisé après l'insertion SQLite pour récupérer l'id, et pour « Dupliquer »)
  Trajet copyWith({
    int? id,
    DateTime? dateDepart,
    int? placesDispo,
    StatutTrajet? statut,
  }) =>
      Trajet(
        id: id ?? this.id,
        conducteurId: conducteurId,
        conducteurNom: conducteurNom,
        conducteurNote: conducteurNote,
        villeDepart: villeDepart,
        villeArrivee: villeArrivee,
        adresseDepart: adresseDepart,
        adresseArrivee: adresseArrivee,
        etapes: etapes,
        dateDepart: dateDepart ?? this.dateDepart,
        dureeMinutes: dureeMinutes,
        distanceKm: distanceKm,
        vehicule: vehicule,
        capaciteVehicule: capaciteVehicule,
        placesTotales: placesTotales,
        placesDispo: placesDispo ?? this.placesDispo,
        prixPlace: prixPlace,
        bagages: bagages,
        fumeur: fumeur,
        animaux: animaux,
        reservationAuto: reservationAuto,
        description: description,
        statut: statut ?? this.statut,
        dateCreation: dateCreation,
      );

  // ------------------------------------------------------------
  // SQLITE : conversion vers / depuis une ligne de la table « trajets »
  // (les booléens sont stockés en 0 / 1, les dates en texte ISO 8601)
  // ------------------------------------------------------------
  Map<String, dynamic> toMap() => {
        // id absent : SQLite le génère (AUTOINCREMENT) lors d'une insertion
        if (id > 0) 'id': id,
        'conducteur_id': conducteurId,
        'conducteur_nom': conducteurNom,
        'conducteur_note': conducteurNote,
        'ville_depart': villeDepart,
        'adresse_depart': adresseDepart,
        'ville_arrivee': villeArrivee,
        'adresse_arrivee': adresseArrivee,
        'date_depart': dateDepart.toIso8601String(),
        'duree_minutes': dureeMinutes,
        'distance_km': distanceKm,
        'vehicule': vehicule,
        'capacite_vehicule': capaciteVehicule,
        'places_totales': placesTotales,
        'places_disponibles': placesDispo,
        'prix_place': prixPlace,
        'bagages': bagages ? 1 : 0,
        'fumeur': fumeur ? 1 : 0,
        'animaux': animaux ? 1 : 0,
        'reservation_auto': reservationAuto ? 1 : 0,
        'description': description,
        'statut': statut.name,
        'date_creation': dateCreation.toIso8601String(),
      };

  factory Trajet.fromMap(Map<String, dynamic> m, {List<Etape>? etapes}) =>
      Trajet(
        id: m['id'] as int,
        conducteurId: m['conducteur_id'] as int,
        conducteurNom: (m['conducteur_nom'] as String?) ?? '',
        conducteurNote: (m['conducteur_note'] as num?)?.toDouble() ?? 5.0,
        villeDepart: m['ville_depart'] as String,
        adresseDepart: (m['adresse_depart'] as String?) ?? '',
        villeArrivee: m['ville_arrivee'] as String,
        adresseArrivee: (m['adresse_arrivee'] as String?) ?? '',
        etapes: etapes,
        dateDepart: DateTime.parse(m['date_depart'] as String),
        dureeMinutes: (m['duree_minutes'] as int?) ?? 60,
        distanceKm: (m['distance_km'] as num?)?.toDouble() ?? 0,
        vehicule: (m['vehicule'] as String?) ?? '',
        capaciteVehicule: (m['capacite_vehicule'] as int?) ?? 4,
        placesTotales: m['places_totales'] as int,
        placesDispo: m['places_disponibles'] as int?,
        prixPlace: (m['prix_place'] as num?)?.toDouble() ?? 0,
        bagages: (m['bagages'] as int? ?? 1) == 1,
        fumeur: (m['fumeur'] as int? ?? 0) == 1,
        animaux: (m['animaux'] as int? ?? 0) == 1,
        reservationAuto: (m['reservation_auto'] as int? ?? 0) == 1,
        description: (m['description'] as String?) ?? '',
        statut: StatutTrajet.values.firstWhere(
          (s) => s.name == m['statut'],
          orElse: () => StatutTrajet.publie,
        ),
        dateCreation: m['date_creation'] != null
            ? DateTime.parse(m['date_creation'] as String)
            : null,
      );
}
