// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/trajet_service.dart
//
//  Les trajets sont enregistrés dans SQLite (TrajetDatabase).
//  Le service garde une copie en mémoire pour que les écrans
//  (et la page d'accueil) puissent lire la liste sans attendre ;
//  chaque modification est d'abord écrite dans SQLite, puis la
//  copie en mémoire est mise à jour et les écrans sont prévenus.
// ============================================================

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/trajet_database.dart';
import '../../../core/utils/geo.dart';
import '../../../models/lieu.dart';
import '../../../models/trajet.dart';

/// Véhicule de l'utilisateur connecté (sera fourni par le module Utilisateur)
const String monVehicule = 'Peugeot 208 – Grise';
const int maCapacite = 4;

class TrajetService extends ChangeNotifier {
  TrajetService._() {
    // Chargement depuis SQLite dès la première utilisation du service
    charger();
  }

  static final TrajetService instance = TrajetService._();

  final TrajetDatabase _db = TrajetDatabase.instance;
  List<Trajet> _trajets = [];
  bool _charge = false;
  Future<void>? _chargement;

  /// true quand les trajets ont été lus depuis SQLite
  bool get estCharge => _charge;

  List<Trajet> get tous => List.unmodifiable(_trajets);

  // ---------- Chargement ----------
  /// Lit tous les trajets dans SQLite (insère la démo si la base est vide).
  /// Le chargement n'a lieu qu'une fois ; les appels suivants attendent le même.
  Future<void> charger() => _chargement ??= _charger();

  /// Relit la base (par exemple après une modification faite ailleurs)
  Future<void> recharger() {
    _chargement = null;
    return charger();
  }

  /// Force le rechargement et l'insertion des données de démonstration
  Future<void> reinitialiserDemo() async {
    _chargement = null;
    if (!kIsWeb) {
      await _db.insertDemoData(_donneesDemo(), force: true);
    }
    await charger();
  }

  Future<void> _charger() async {
    try {
      if (kIsWeb) {
        _trajets = _donneesDemo();
      } else {
        await _db.insertDemoData(_donneesDemo());
        _trajets = await _db.readAll();
      }
      await _mettreAJourStatuts();
    } catch (e) {
      debugPrint('TrajetService : erreur de chargement SQLite : $e');
      _trajets = _donneesDemo();
    } finally {
      _charge = true;
      notifyListeners();
    }
  }

  Trajet? parId(int id) {
    for (final t in _trajets) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------- Lecture (utilisé par l'accueil et les écrans) ----------
  /// Trajets publiés par [userId]. Avec `aVenir: true`, seulement les
  /// trajets encore actifs (ni terminés ni annulés), du plus proche au plus lointain.
  List<Trajet> mesTrajets(int userId, {bool aVenir = false}) {
    return _trajets.where((t) {
      if (t.conducteurId != userId) return false;
      if (aVenir) return t.statut.estActif;
      return true;
    }).toList()
      ..sort((a, b) => a.dateDepart.compareTo(b.dateDepart));
  }

  /// Trajets terminés ou annulés, du plus récent au plus ancien
  List<Trajet> historique(int userId) {
    return _trajets
        .where((t) => t.conducteurId == userId && !t.statut.estActif)
        .toList()
      ..sort((a, b) => b.dateDepart.compareTo(a.dateDepart));
  }

  /// Recherche avec filtres.
  /// Si [lieuDepart] / [lieuArrivee] sont donnés (choisis sur la carte),
  /// on garde les trajets qui partent / arrivent à moins de [rayonKm] ;
  /// pour les anciens trajets sans coordonnées, on compare la ville.
  List<Trajet> rechercher({
    String depart = '',
    String arrivee = '',
    Lieu? lieuDepart,
    Lieu? lieuArrivee,
    double rayonKm = 15,
    DateTime? date,
    int placesMin = 1,
    double? prixMax,
    String tri = 'heure',
  }) {
    final d = depart.trim().toLowerCase();
    final a = arrivee.trim().toLowerCase();

    final res = _trajets.where((t) {
      if (!t.estReservable) return false;
      if (!_correspond(t.villeDepart, t.latDepart, t.lngDepart, d, lieuDepart,
          rayonKm)) {
        return false;
      }
      if (!_correspond(t.villeArrivee, t.latArrivee, t.lngArrivee, a,
          lieuArrivee, rayonKm)) {
        return false;
      }
      if (date != null &&
          (t.dateDepart.year != date.year ||
              t.dateDepart.month != date.month ||
              t.dateDepart.day != date.day)) {
        return false;
      }
      if (t.placesDispo < placesMin) return false;
      if (prixMax != null && t.prixPlace > prixMax) return false;
      return true;
    }).toList();

    switch (tri) {
      case 'prix':
        res.sort((x, y) => x.prixPlace.compareTo(y.prixPlace));
        break;
      case 'note':
        res.sort((x, y) => y.conducteurNote.compareTo(x.conducteurNote));
        break;
      default:
        res.sort((x, y) => x.dateDepart.compareTo(y.dateDepart));
    }
    return res;
  }

  /// Le point (ville + coordonnées) d'un trajet correspond-il à la recherche ?
  bool _correspond(String ville, double? lat, double? lng, String texte,
      Lieu? lieu, double rayonKm) {
    if (lieu != null && lat != null && lng != null) {
      return distanceEntre(lieu.lat, lieu.lng, lat, lng) <= rayonKm;
    }
    if (texte.isEmpty) return true;
    return ville.toLowerCase().contains(texte);
  }

  // ---------- Publier, dupliquer ----------
  /// Enregistre un nouveau trajet (id = 0) dans SQLite.
  /// Retourne null si tout va bien, sinon le message d'erreur.
  Future<String?> publier(Trajet t) async {
    await charger();
    final erreur = t.valider();
    if (erreur != null) return erreur;

    // Règle : pas deux trajets du même conducteur à moins d'1 h d'écart
    final conflit = _trajets.any((a) =>
        a.conducteurId == t.conducteurId &&
        a.statut.estActif &&
        a.dateDepart.difference(t.dateDepart).inMinutes.abs() < 60);
    if (conflit) return 'Vous avez déjà un trajet prévu à cette heure-là.';

    try {
      Trajet enregistre;
      if (kIsWeb) {
        final newId = _trajets.isEmpty ? 1 : (_trajets.map((x) => x.id).reduce((a, b) => a > b ? a : b) + 1);
        enregistre = t.copyWith(id: newId, statut: StatutTrajet.publie);
        _trajets.add(enregistre);
      } else {
        enregistre = await _db.create(t.copyWith(statut: StatutTrajet.publie));
        _trajets.add(enregistre);
      }
      notifyListeners();
      return null;
    } catch (e) {
      final newId = _trajets.isEmpty ? 1 : (_trajets.map((x) => x.id).reduce((a, b) => a > b ? a : b) + 1);
      final enregistre = t.copyWith(id: newId, statut: StatutTrajet.publie);
      _trajets.add(enregistre);
      notifyListeners();
      return null;
    }
  }

  // ---------- Modifier ----------
  /// Met à jour un trajet existant dans SQLite (UPDATE).
  /// Retourne null si tout va bien, sinon le message d'erreur.
  Future<String?> modifier(Trajet t) async {
    await charger();
    final ancien = parId(t.id);
    if (ancien == null) return 'Trajet introuvable.';

    // Règle : on ne modifie qu'un trajet publié ou complet
    if (ancien.statut != StatutTrajet.publie &&
        ancien.statut != StatutTrajet.complet) {
      return 'Ce trajet ne peut plus être modifié (${ancien.statut.libelle.toLowerCase()}).';
    }

    // Règle : on ne peut pas proposer moins de places que celles déjà réservées
    final reservees = ancien.placesReservees;
    if (t.placesTotales < reservees) {
      return 'Impossible : $reservees place(s) sont déjà réservée(s).';
    }

    // Règle : si des passagers ont réservé, l'itinéraire et la date sont figés
    if (reservees > 0 &&
        (t.villeDepart.toLowerCase() != ancien.villeDepart.toLowerCase() ||
            t.villeArrivee.toLowerCase() != ancien.villeArrivee.toLowerCase() ||
            _pointDeplace(ancien.latDepart, ancien.lngDepart, t.latDepart,
                t.lngDepart) ||
            _pointDeplace(ancien.latArrivee, ancien.lngArrivee, t.latArrivee,
                t.lngArrivee) ||
            !t.dateDepart.isAtSameMomentAs(ancien.dateDepart))) {
      return 'Des passagers ont déjà réservé : vous ne pouvez plus changer '
          'l’itinéraire ni la date. Annulez le trajet si nécessaire.';
    }

    final erreur = t.valider();
    if (erreur != null) return erreur;

    // Règle : pas deux trajets du même conducteur à moins d'1 h d'écart
    final conflit = _trajets.any((a) =>
        a.id != t.id &&
        a.conducteurId == t.conducteurId &&
        a.statut.estActif &&
        a.dateDepart.difference(t.dateDepart).inMinutes.abs() < 60);
    if (conflit) return 'Vous avez déjà un trajet prévu à cette heure-là.';

    // Les places libres sont recalculées à partir des réservations existantes
    final dispo = t.placesTotales - reservees;
    try {
      await _enregistrer(t.copyWith(
        placesDispo: dispo,
        statut: dispo == 0 ? StatutTrajet.complet : StatutTrajet.publie,
      ));
      return null;
    } catch (e) {
      return 'Erreur d’enregistrement : $e';
    }
  }

  /// true si un point déjà placé sur la carte a été déplacé de plus de 300 m
  bool _pointDeplace(double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return false;
    }
    return distanceEntre(lat1, lng1, lat2, lng2) > 0.3;
  }

  /// Duplique un trajet une semaine plus tard
  Future<String?> dupliquer(Trajet t) {
    var date = t.dateDepart.add(const Duration(days: 7));
    while (date.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      date = date.add(const Duration(days: 7));
    }
    return publier(t.copyWith(
      id: 0,
      dateDepart: date,
      placesDispo: t.placesTotales,
      statut: StatutTrajet.publie,
    ));
  }

  // ---------- Places (appelé par le module Réservation) ----------
  Future<bool> reserverPlaces(int trajetId, int nb) async {
    final t = parId(trajetId);
    if (t == null || nb < 1 || t.placesDispo < nb) return false;
    final restantes = t.placesDispo - nb;
    await _enregistrer(t.copyWith(
      placesDispo: restantes,
      statut: restantes == 0 ? StatutTrajet.complet : t.statut,
    ));
    return true;
  }

  Future<void> libererPlaces(int trajetId, int nb) async {
    final t = parId(trajetId);
    if (t == null) return;
    final dispo = (t.placesDispo + nb).clamp(0, t.placesTotales);
    await _enregistrer(t.copyWith(
      placesDispo: dispo,
      statut: t.statut == StatutTrajet.complet && dispo > 0
          ? StatutTrajet.publie
          : t.statut,
    ));
  }

  // ---------- Cycle de vie ----------
  Future<void> demarrer(int id) => _changerStatut(id, StatutTrajet.enCours);
  Future<void> terminer(int id) => _changerStatut(id, StatutTrajet.termine);
  Future<void> annuler(int id) => _changerStatut(id, StatutTrajet.annule);

  /// Supprime définitivement un trajet de SQLite (DELETE).
  /// Retourne null si tout va bien, sinon le message d'erreur.
  Future<String?> supprimer(int id) async {
    final t = parId(id);
    if (t == null) return 'Trajet introuvable.';

    // Règle : un trajet avec des passagers ne se supprime pas, il s'annule
    if (t.statut.estActif && t.placesReservees > 0) {
      return 'Des places sont réservées : annulez le trajet au lieu de le supprimer.';
    }
    if (t.statut == StatutTrajet.enCours) {
      return 'Un trajet en cours ne peut pas être supprimé.';
    }

    try {
      if (!kIsWeb) {
        await _db.delete(id); // les étapes sont supprimées par ON DELETE CASCADE
      }
      _trajets.removeWhere((x) => x.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      _trajets.removeWhere((x) => x.id == id);
      notifyListeners();
      return null;
    }
  }

  Future<void> _changerStatut(int id, StatutTrajet s) async {
    final t = parId(id);
    if (t == null) return;
    await _enregistrer(t.copyWith(statut: s));
  }

  /// Écrit le trajet dans SQLite puis remplace la copie en mémoire
  Future<void> _enregistrer(Trajet t) async {
    if (!kIsWeb) {
      try {
        await _db.update(t);
      } catch (e) {
        debugPrint('Erreur DB update: $e');
      }
    }
    final i = _trajets.indexWhere((x) => x.id == t.id);
    if (i != -1) _trajets[i] = t;
    notifyListeners();
  }

  /// Règle : un trajet publié ou complet dont le départ est passé
  /// depuis plus de 24 h passe automatiquement en « Terminé ».
  Future<void> _mettreAJourStatuts() async {
    final limite = DateTime.now().subtract(const Duration(hours: 24));
    for (var i = 0; i < _trajets.length; i++) {
      final t = _trajets[i];
      if ((t.statut == StatutTrajet.publie ||
              t.statut == StatutTrajet.complet) &&
          t.dateDepart.isBefore(limite)) {
        final termine = t.copyWith(statut: StatutTrajet.termine);
        await _db.update(termine);
        _trajets[i] = termine;
      }
    }
  }
}

// ------------------------------------------------------------
// DONNÉES DE DÉMONSTRATION
// Insérées dans SQLite au premier lancement seulement (table vide).
// id = 0 : SQLite attribue les identifiants.
// ------------------------------------------------------------
List<Trajet> _donneesDemo() {
  final n = DateTime.now();
  DateTime j(int jours, int h, int m) =>
      DateTime(n.year, n.month, n.day + jours, h, m);

  return [
    Trajet(
      id: 0,
      conducteurId: monId,
      conducteurNom: monNom,
      villeDepart: 'Tunis',
      villeArrivee: 'Hammamet',
      adresseDepart: 'Place Barcelone',
      latDepart: 36.7955,
      lngDepart: 10.1806,
      latArrivee: 36.4000,
      lngArrivee: 10.6167,
      dateDepart: j(2, 8, 30),
      dureeMinutes: 70,
      distanceKm: 63,
      vehicule: 'Peugeot 208',
      placesTotales: 4,
      placesDispo: 2,
      prixPlace: 12,
      description: 'Départ matinal vers Hammamet.',
    ),
    Trajet(
      id: 0,
      conducteurId: 2,
      conducteurNom: 'Ahmed B.',
      conducteurNote: 4.8,
      vehicule: 'Volkswagen Golf – Noire',
      villeDepart: 'Tunis',
      adresseDepart: 'Place Barcelone',
      villeArrivee: 'Sousse',
      adresseArrivee: 'Gare routière',
      latDepart: 36.7955,
      lngDepart: 10.1806,
      latArrivee: 35.8254,
      lngArrivee: 10.6370,
      dateDepart: j(1, 17, 30),
      dureeMinutes: 135,
      distanceKm: 143,
      placesTotales: 3,
      placesDispo: 2,
      prixPlace: 18,
      description: 'Départ ponctuel, petit bagage accepté.',
      etapes: const [Etape(ville: 'Enfidha', ordre: 1, prix: 12)],
    ),
    Trajet(
      id: 0,
      conducteurId: 3,
      conducteurNom: 'Salma K.',
      conducteurNote: 4.9,
      vehicule: 'Renault Clio – Blanche',
      villeDepart: 'Tunis',
      adresseDepart: 'Ariana Soghra',
      villeArrivee: 'Sfax',
      latDepart: 36.8860,
      lngDepart: 10.1860,
      latArrivee: 34.7406,
      lngArrivee: 10.7603,
      dateDepart: j(1, 7, 0),
      dureeMinutes: 210,
      distanceKm: 270,
      placesTotales: 4,
      placesDispo: 3,
      prixPlace: 30,
      animaux: true,
      reservationAuto: true,
      description: 'Trajet direct par l’autoroute A1.',
    ),
    Trajet(
      id: 0,
      conducteurId: 4,
      conducteurNom: 'Mehdi T.',
      conducteurNote: 4.3,
      vehicule: 'Hyundai i10 – Bleue',
      villeDepart: 'Bizerte',
      villeArrivee: 'Tunis',
      latDepart: 37.2744,
      lngDepart: 9.8739,
      latArrivee: 36.8065,
      lngArrivee: 10.1815,
      dateDepart: j(1, 6, 45),
      dureeMinutes: 80,
      distanceKm: 66,
      placesTotales: 3,
      placesDispo: 1,
      prixPlace: 9,
      description: 'Trajet quotidien travail / études.',
    ),
    Trajet(
      id: 0,
      conducteurId: 5,
      conducteurNom: 'Mariem B.',
      conducteurNote: 4.9,
      vehicule: 'Seat Ibiza – Grise',
      villeDepart: 'Sousse',
      villeArrivee: 'Monastir',
      latDepart: 35.8254,
      lngDepart: 10.6370,
      latArrivee: 35.7780,
      lngArrivee: 10.8261,
      dateDepart: j(1, 8, 0),
      dureeMinutes: 30,
      distanceKm: 22,
      placesTotales: 4,
      placesDispo: 3,
      prixPlace: 5,
      description: 'Navette universitaire Sousse - Monastir.',
    ),
    Trajet(
      id: 0,
      conducteurId: 6,
      conducteurNom: 'Nader Z.',
      conducteurNote: 4.6,
      vehicule: 'Dacia Logan – Blanche',
      villeDepart: 'Sfax',
      villeArrivee: 'Gabès',
      latDepart: 34.7406,
      lngDepart: 10.7603,
      latArrivee: 33.8815,
      lngArrivee: 10.0982,
      dateDepart: j(2, 13, 0),
      dureeMinutes: 120,
      distanceKm: 150,
      placesTotales: 4,
      placesDispo: 2,
      prixPlace: 15,
      description: 'Voyage vers le sud.',
    ),
    Trajet(
      id: 0,
      conducteurId: 7,
      conducteurNom: 'Chaima R.',
      conducteurNote: 4.7,
      vehicule: 'Peugeot 301 – Noire',
      villeDepart: 'Nabeul',
      villeArrivee: 'Tunis',
      latDepart: 36.4561,
      lngDepart: 10.7376,
      latArrivee: 36.8065,
      lngArrivee: 10.1815,
      dateDepart: j(1, 7, 30),
      dureeMinutes: 75,
      distanceKm: 68,
      placesTotales: 3,
      placesDispo: 2,
      prixPlace: 10,
      description: 'Départ matinal Nabeul vers Tunis.',
    ),
    Trajet(
      id: 0,
      conducteurId: monId,
      conducteurNom: monNom,
      vehicule: monVehicule,
      villeDepart: 'Tunis',
      adresseDepart: 'Mnihla',
      villeArrivee: 'Nabeul',
      latDepart: 36.8570,
      lngDepart: 10.1070,
      latArrivee: 36.4561,
      lngArrivee: 10.7376,
      dateDepart: j(4, 9, 15),
      dureeMinutes: 90,
      distanceKm: 67,
      placesTotales: 3,
      placesDispo: 3,
      prixPlace: 10,
    ),
    Trajet(
      id: 0,
      conducteurId: monId,
      conducteurNom: monNom,
      vehicule: monVehicule,
      villeDepart: 'Tunis',
      villeArrivee: 'Sousse',
      latDepart: 36.8065,
      lngDepart: 10.1815,
      latArrivee: 35.8254,
      lngArrivee: 10.6370,
      dateDepart: j(-5, 14, 0),
      dureeMinutes: 130,
      distanceKm: 143,
      placesTotales: 4,
      placesDispo: 0,
      prixPlace: 18,
      statut: StatutTrajet.termine,
    ),
  ];
}
