// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/trajet_service.dart
//
//  Les trajets sont enregistrés dans SQLite (TrajetDatabase).
//  Le service garde une copie en mémoire pour que les écrans
//  (et la page d'accueil) puissent lire la liste sans attendre ;
//  chaque modification est d'abord écrite dans SQLite, puis la
//  copie en mémoire est mise à jour et les écrans sont prévenus.
//  La série (trajet régulier) et l'option « Entre filles » sont
//  enregistrées à part, dans complements.db.
// ============================================================

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/complements_database.dart';
import '../../../core/services/trajet_database.dart';
import '../../../core/utils/geo.dart';
import '../../../models/lieu.dart';
import '../../user/services/user_service.dart';
import '../../../models/trajet.dart';
import '../utils/trajet_format.dart';
import 'discussion_service.dart';
import 'notification_service.dart';

/// Véhicule de l'utilisateur connecté (profil du module Utilisateur),
/// ou le véhicule de démonstration s'il n'en a pas renseigné
String get monVehicule {
  final u = UserService.instance.currentUser;
  final modele = [u?.marqueVehicule, u?.modeleVehicule]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .join(' ');
  if (modele.isEmpty) return 'Peugeot 208 – Grise';
  final couleur = u?.couleurVehicule?.trim() ?? '';
  return couleur.isEmpty ? modele : '$modele – $couleur';
}
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
  /// Le chargement n'a lieu qu'une fois par utilisateur ; les appels suivants
  /// attendent le même. Si un autre utilisateur s'est connecté depuis, les
  /// trajets, discussions et notifications sont relus pour lui.
  Future<void> charger() {
    if (_chargePour != null && _chargePour != monId) {
      _chargement = null;
      DiscussionService.instance.reinitialiser();
      NotificationService.instance.reinitialiser();
    }
    return _chargement ??= _charger();
  }

  /// Utilisateur (monId) pour lequel les données ont été chargées
  int? _chargePour;

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
    _chargePour = monId;
    try {
      if (kIsWeb) {
        _trajets = _donneesDemoNumerotees();
      } else {
        await _db.insertDemoData(_donneesDemo());
        _trajets = await _avecOptions(await _db.readAll());
      }
      await _mettreAJourStatuts();
    } catch (e) {
      debugPrint('TrajetService : erreur de chargement SQLite : $e');
      _trajets = _donneesDemoNumerotees();
    } finally {
      // Passagers et discussions des trajets (base « discussions.db »)
      await DiscussionService.instance.charger(_trajets);
      _charge = true;
      // Notifications et alertes (base « complements.db »)
      await NotificationService.instance.charger();
      notifyListeners();
    }
  }

  /// Ajoute aux trajets lus dans SQLite leur série et l'option
  /// « Entre filles » (complements.db)
  Future<List<Trajet>> _avecOptions(List<Trajet> trajets) async {
    final base = ComplementsDatabase.instance;
    try {
      var options = await base.lireOptions();
      if (options.isEmpty) {
        // Premier lancement : options des trajets de démonstration
        for (final d in _donneesDemo().where((d) => d.entreFilles)) {
          for (final t in trajets) {
            if (t.conducteurId == d.conducteurId &&
                t.villeDepart == d.villeDepart &&
                t.villeArrivee == d.villeArrivee) {
              await base.enregistrerOptions(t.id, null, true);
            }
          }
        }
        options = await base.lireOptions();
      }
      return [
        for (final t in trajets)
          if (options[t.id] case final o?)
            t.copyWith(serieId: o.serieId, entreFilles: o.entreFilles)
          else
            t,
      ];
    } catch (e) {
      debugPrint('TrajetService : options des trajets illisibles : $e');
      return trajets;
    }
  }

  /// Enregistre la série et l'option « Entre filles » du trajet
  Future<void> _enregistrerOptions(Trajet t) async {
    if (kIsWeb) return;
    try {
      await ComplementsDatabase.instance
          .enregistrerOptions(t.id, t.serieId, t.entreFilles);
    } catch (e) {
      debugPrint('TrajetService : erreur d’enregistrement des options : $e');
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
    bool nonFumeur = false,
    bool bagages = false,
    bool animaux = false,
    bool entreFilles = false,
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
      // Préférences du passager
      if (nonFumeur && t.fumeur) return false;
      if (bagages && !t.bagages) return false;
      if (animaux && !t.animaux) return false;
      if (entreFilles && !t.entreFilles) return false;
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

    int prochainId() => _trajets.isEmpty
        ? 1
        : _trajets.map((x) => x.id).reduce((a, b) => a > b ? a : b) + 1;
    Trajet enregistre;
    try {
      enregistre = kIsWeb
          ? t.copyWith(id: prochainId(), statut: StatutTrajet.publie)
          : await _db.create(t.copyWith(statut: StatutTrajet.publie));
    } catch (e) {
      enregistre = t.copyWith(id: prochainId(), statut: StatutTrajet.publie);
    }
    _trajets.add(enregistre);
    await _enregistrerOptions(enregistre);
    notifyListeners();
    return null;
  }

  /// Publie un trajet régulier : un trajet par date, tous dans la même
  /// série (chacun reste modifiable ou annulable séparément). Les dates
  /// refusées par les règles (conflit d'horaire…) sont ignorées et
  /// expliquées dans [refus].
  Future<({int publies, List<String> refus})> publierSerie(
      Trajet modele, List<DateTime> dates) async {
    final serie = 'serie-${DateTime.now().microsecondsSinceEpoch}';
    var publies = 0;
    final refus = <String>[];
    for (final d in dates) {
      final erreur =
          await publier(modele.copyWith(id: 0, dateDepart: d, serieId: serie));
      if (erreur == null) {
        publies++;
      } else {
        refus.add('${tJourSemaine(d)} ${tDateCourte(d)} : $erreur');
      }
    }
    return (publies: publies, refus: refus);
  }

  /// Trajets encore à venir d'une série, du plus proche au plus lointain
  List<Trajet> prochainsDeSerie(String serieId) => _trajets
      .where((t) =>
          t.serieId == serieId &&
          (t.statut == StatutTrajet.publie || t.statut == StatutTrajet.complet))
      .toList()
    ..sort((a, b) => a.dateDepart.compareTo(b.dateDepart));

  /// Annule [t] et les trajets suivants de sa série (les passagers sont
  /// prévenus). Retourne le nombre de trajets annulés.
  Future<int> annulerSerie(Trajet t) async {
    final serie = t.serieId;
    if (serie == null) return 0;
    final cibles = prochainsDeSerie(serie)
        .where((x) => !x.dateDepart.isBefore(t.dateDepart))
        .toList();
    for (final x in cibles) {
      await annuler(x.id);
    }
    return cibles.length;
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
      final maj = t.copyWith(
        placesDispo: dispo,
        statut: dispo == 0 ? StatutTrajet.complet : StatutTrajet.publie,
      );
      await _enregistrer(maj);
      await _enregistrerOptions(maj);
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
      sansSerie: true,
    ));
  }

  // ---------- Places (appelé par le module Réservation) ----------
  /// Réserve [nb] places pour le passager (par défaut l'utilisateur
  /// connecté), qui rejoint la discussion du trajet.
  Future<bool> reserverPlaces(
    int trajetId,
    int nb, {
    int? passagerId,
    String? passagerNom,
  }) async {
    passagerId ??= monId;
    passagerNom ??= monNom;
    final t = parId(trajetId);
    if (t == null || nb < 1 || t.placesDispo < nb) return false;
    // Règle : un conducteur ne réserve pas de place sur son propre trajet
    if (t.conducteurId == passagerId) return false;
    final restantes = t.placesDispo - nb;
    await _enregistrer(t.copyWith(
      placesDispo: restantes,
      statut: restantes == 0 ? StatutTrajet.complet : t.statut,
    ));
    await DiscussionService.instance
        .ajouterPassager(trajetId, passagerId, passagerNom, nb);
    return true;
  }

  /// Libère [nb] places ; avec [passagerId], sa réservation est réduite
  /// d'autant (il quitte la discussion s'il n'a plus de place).
  Future<void> libererPlaces(int trajetId, int nb, {int? passagerId}) async {
    final t = parId(trajetId);
    if (t == null) return;
    final dispo = (t.placesDispo + nb).clamp(0, t.placesTotales);
    await _enregistrer(t.copyWith(
      placesDispo: dispo,
      statut: t.statut == StatutTrajet.complet && dispo > 0
          ? StatutTrajet.publie
          : t.statut,
    ));
    if (passagerId != null) {
      await DiscussionService.instance.retirerPassager(trajetId, passagerId, nb);
    }
  }

  /// Le passager annule sa réservation (jusqu'à 30 min avant le départ) :
  /// ses places sont libérées et la discussion du trajet est prévenue.
  /// Retourne null si tout va bien, sinon le message d'erreur.
  Future<String?> annulerReservation(int trajetId,
      {int? passagerId}) async {
    passagerId ??= monId;
    final t = parId(trajetId);
    if (t == null) return 'Trajet introuvable.';
    final discussions = DiscussionService.instance;
    final refus = discussions.motifRefusAnnulation(t, passagerId);
    if (refus != null) return refus;

    final reservation = discussions.reservationDe(trajetId, passagerId)!;
    await discussions.annoncerAnnulation(t, reservation.nom);
    await NotificationService.instance.signalerAnnulation(t, reservation);
    await libererPlaces(trajetId, reservation.places, passagerId: passagerId);
    return null;
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
    } catch (e) {
      debugPrint('Erreur DB delete: $e');
    }
    _trajets.removeWhere((x) => x.id == id);
    notifyListeners();
    // Les passagers, la discussion, les notifications et les options
    // sont dans d'autres bases
    await DiscussionService.instance.supprimerTrajet(id);
    await NotificationService.instance.supprimerTrajet(id);
    return null;
  }

  Future<void> _changerStatut(int id, StatutTrajet s) async {
    final t = parId(id);
    if (t == null) return;
    final maj = t.copyWith(statut: s);
    await _enregistrer(maj);
    // Les passagers sont prévenus dans la discussion du trajet
    await DiscussionService.instance.signalerStatut(maj, s);
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

/// Dates d'un trajet régulier : à partir de [premier] (inclus, même
/// heure), chaque jour de la semaine choisi dans [jours]
/// ([DateTime.monday] … [DateTime.sunday]), pendant [semaines] semaines
List<DateTime> datesSerie(DateTime premier, Set<int> jours, int semaines) => [
      for (var i = 0; i < semaines * 7; i++)
        if (jours.contains(
            DateTime(premier.year, premier.month, premier.day + i).weekday))
          DateTime(premier.year, premier.month, premier.day + i, premier.hour,
              premier.minute),
    ];

// ------------------------------------------------------------
// DONNÉES DE DÉMONSTRATION
// Insérées dans SQLite au premier lancement seulement (table vide).
// id = 0 : SQLite attribue les identifiants.
// ------------------------------------------------------------

/// Données de démo gardées en mémoire, sans SQLite (web, ou base
/// inaccessible) : on numérote nous-mêmes les trajets (1, 2, 3…),
/// sinon parId() renverrait toujours le premier.
List<Trajet> _donneesDemoNumerotees() {
  final demo = _donneesDemo();
  return [for (var i = 0; i < demo.length; i++) demo[i].copyWith(id: i + 1)];
}

List<Trajet> _donneesDemo() {
  final n = DateTime.now();
  DateTime j(int jours, int h, int m) =>
      DateTime(n.year, n.month, n.day + jours, h, m);
  // Départ dans ~1 h 15 (arrondi à 5 min) : sa discussion est déjà ouverte
  final bientot = DateTime(n.year, n.month, n.day, n.hour,
      n.minute - n.minute % 5 + 75);

  return [
    Trajet(
      id: 0,
      conducteurId: monId,
      conducteurNom: monNom,
      vehicule: monVehicule,
      villeDepart: 'Tunis',
      adresseDepart: 'Les Berges du Lac 2',
      villeArrivee: 'Ariana',
      adresseArrivee: 'ESPRIT, El Ghazela',
      latDepart: 36.8450,
      lngDepart: 10.2730,
      latArrivee: 36.8992,
      lngArrivee: 10.1897,
      dateDepart: bientot,
      dureeMinutes: 25,
      distanceKm: 14,
      placesTotales: 3,
      placesDispo: 1,
      prixPlace: 3,
      description: 'Navette du matin vers ESPRIT.',
    ),
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
      entreFilles: true,
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
      entreFilles: true,
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
    // Trajet passé d'un autre conducteur : l'utilisateur y était passager
    // et peut noter le conducteur
    Trajet(
      id: 0,
      conducteurId: 8,
      conducteurNom: 'Sami R.',
      conducteurNote: 4.5,
      vehicule: 'Kia Picanto – Rouge',
      villeDepart: 'Tunis',
      adresseDepart: 'Bab Saadoun',
      villeArrivee: 'Bizerte',
      latDepart: 36.8065,
      lngDepart: 10.1650,
      latArrivee: 37.2744,
      lngArrivee: 9.8739,
      dateDepart: j(-3, 17, 0),
      dureeMinutes: 70,
      distanceKm: 66,
      placesTotales: 3,
      placesDispo: 1,
      prixPlace: 9,
      statut: StatutTrajet.termine,
    ),
  ];
}
