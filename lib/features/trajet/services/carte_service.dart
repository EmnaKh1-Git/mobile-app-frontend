// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/carte_service.dart
//
//  Tout ce qui concerne la carte, SANS clé API (OpenStreetMap) :
//   - position GPS du téléphone ............ geolocator
//   - recherche d'adresse pendant la saisie . Photon (photon.komoot.io)
//   - adresse d'un point de la carte ........ Photon, secours Nominatim
//   - itinéraire routier, distance, durée ... OSRM (router.project-osrm.org)
//   - lieux récents / enregistrés ........... SQLite (TrajetDatabase)
//
//  Les serveurs publics gratuits demandent un usage raisonnable :
//  la saisie est temporisée (debounce) et les itinéraires sont mis en cache.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/services/trajet_database.dart';
import '../../../core/utils/geo.dart';
import '../../../models/lieu.dart';
import '../../../models/trajet.dart';

/// Itinéraire calculé entre deux points
class Itineraire {
  final LatLng depart;
  final LatLng arrivee;

  /// Points du tracé de la route (au moins [depart, arrivee])
  final List<LatLng> points;
  final double distanceKm;
  final int dureeMinutes;

  /// true : pas de réseau, distance estimée à vol d'oiseau × 1,3
  final bool approximatif;

  const Itineraire({
    required this.depart,
    required this.arrivee,
    required this.points,
    required this.distanceKm,
    required this.dureeMinutes,
    this.approximatif = false,
  });
}

class CarteService {
  CarteService._();
  static final CarteService instance = CarteService._();

  /// Centre par défaut si le GPS n'est pas disponible : Tunis
  static const LatLng tunis = LatLng(36.8065, 10.1815);

  /// Zone de recherche des adresses : Tunisie (lon min, lat min, lon max, lat max)
  static const String _zoneTunisie = '7.5,30.2,11.6,37.6';

  /// OSRM ne connaît pas la circulation : on ajoute une marge de 15 %
  static const double _margeCirculation = 1.15;

  static const Duration _delaiReseau = Duration(seconds: 12);
  static const Map<String, String> _entetes = {
    // Nominatim / Photon demandent d'identifier l'application
    'User-Agent': 'CovoiturageEtudiant/1.0 (Flutter)',
    'Accept': 'application/json',
  };

  LatLng? _dernierePosition;
  final Map<String, Itineraire> _cacheItineraires = {};

  /// Dernière position GPS connue (ou Tunis)
  LatLng get positionConnue => _dernierePosition ?? tunis;

  // ============================================================
  // 1. POSITION GPS
  // ============================================================

  /// Position actuelle du téléphone, ou null si la localisation est
  /// désactivée ou refusée.
  Future<LatLng?> positionActuelle() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        _dernierePosition = LatLng(p.latitude, p.longitude);
      } on TimeoutException {
        // Pas de position fraîche : on prend la dernière connue du téléphone
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) _dernierePosition = LatLng(p.latitude, p.longitude);
      }
      return _dernierePosition;
    } catch (e) {
      debugPrint('CarteService : position indisponible : $e');
      return _dernierePosition;
    }
  }

  // ============================================================
  // 2. RECHERCHE D'ADRESSES (pendant la saisie)
  // ============================================================

  /// Lieux correspondant au texte saisi, les plus proches en premier.
  Future<List<Lieu>> rechercher(String texte) async {
    final q = texte.trim();
    if (q.length < 2) return [];
    final centre = positionConnue;

    final data = await _getJson(Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'lang': 'fr',
      'limit': '10',
      'lat': centre.latitude.toStringAsFixed(5),
      'lon': centre.longitude.toStringAsFixed(5),
      'bbox': _zoneTunisie,
    }));
    if (data is! Map || data['features'] is! List) return [];

    final res = <Lieu>[];
    for (final f in data['features'] as List) {
      final lieu = _lieuPhoton(f);
      // Évite les doublons (même nom, même complément)
      if (lieu != null &&
          !res.any((l) => l.nom == lieu.nom && l.adresse == lieu.adresse)) {
        res.add(lieu);
      }
    }
    return res;
  }

  // ============================================================
  // 3. ADRESSE D'UN POINT (quand on déplace la carte)
  // ============================================================

  /// Nom de la rue / du lieu situé au point [p].
  /// Ne renvoie jamais null : en dernier recours, les coordonnées.
  Future<Lieu> adresseDe(LatLng p) async {
    // a) Photon
    final data = await _getJson(Uri.https('photon.komoot.io', '/reverse', {
      'lat': p.latitude.toStringAsFixed(6),
      'lon': p.longitude.toStringAsFixed(6),
      'lang': 'fr',
      'limit': '1',
    }));
    if (data is Map && data['features'] is List) {
      final features = data['features'] as List;
      if (features.isNotEmpty) {
        final l = _lieuPhoton(features.first);
        if (l != null) {
          // On garde la position exacte du repère, pas celle de la rue
          return Lieu(
              nom: l.nom,
              adresse: l.adresse,
              ville: l.ville,
              lat: p.latitude,
              lng: p.longitude);
        }
      }
    }

    // b) Secours : Nominatim
    final n = await _getJson(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': p.latitude.toStringAsFixed(6),
      'lon': p.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'fr',
    }));
    if (n is Map && n['address'] is Map) {
      final a = (n['address'] as Map).cast<String, dynamic>();
      final rue = _texte(a, 'road');
      final nom = _texte(n.cast<String, dynamic>(), 'name');
      final ville = _premier(a, ['city', 'town', 'village', 'county', 'state']);
      final quartier =
          _premier(a, ['suburb', 'neighbourhood', 'quarter', 'city_district']);
      final titre = nom.isNotEmpty ? nom : (rue.isNotEmpty ? rue : quartier);
      if (titre.isNotEmpty) {
        return Lieu(
          nom: titre,
          adresse: _joindre([if (titre != rue) rue, quartier, ville], titre),
          ville: ville,
          lat: p.latitude,
          lng: p.longitude,
        );
      }
    }

    // c) Rien trouvé (pas de réseau…)
    return Lieu(
      nom: 'Point sur la carte',
      adresse:
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
      lat: p.latitude,
      lng: p.longitude,
    );
  }

  // ============================================================
  // 4. ITINÉRAIRE : distance + durée + tracé
  // ============================================================

  /// Itinéraire en voiture de [a] à [b] (OSRM). Sans réseau, renvoie une
  /// estimation (vol d'oiseau × 1,3 à 50 km/h) marquée « approximatif ».
  Future<Itineraire> itineraire(LatLng a, LatLng b) async {
    final cle = '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}'
        ';${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';
    final enCache = _cacheItineraires[cle];
    if (enCache != null) return enCache;

    final coords = '${a.longitude.toStringAsFixed(6)},${a.latitude.toStringAsFixed(6)};'
        '${b.longitude.toStringAsFixed(6)},${b.latitude.toStringAsFixed(6)}';
    final data = await _getJson(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
        '?overview=full&geometries=geojson&alternatives=false&steps=false'));

    try {
      if (data is Map && data['code'] == 'Ok') {
        final route = (data['routes'] as List).first as Map;
        final geo = (route['geometry'] as Map)['coordinates'] as List;
        final points = <LatLng>[
          for (final c in geo)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ];
        final secondes = (route['duration'] as num).toDouble();
        final it = Itineraire(
          depart: a,
          arrivee: b,
          points: points.length >= 2 ? points : [a, b],
          distanceKm: (route['distance'] as num).toDouble() / 1000,
          dureeMinutes:
              math.max(1, (secondes / 60 * _margeCirculation).round()),
        );
        _cacheItineraires[cle] = it;
        return it;
      }
    } catch (e) {
      debugPrint('CarteService : réponse OSRM illisible : $e');
    }

    // Secours hors ligne
    final km = distanceEntre(a.latitude, a.longitude, b.latitude, b.longitude) * 1.3;
    return Itineraire(
      depart: a,
      arrivee: b,
      points: [a, b],
      distanceKm: km,
      dureeMinutes: math.max(1, (km / 50 * 60).round()),
      approximatif: true,
    );
  }

  /// Itinéraire d'un trajet déjà publié (page détail) :
  ///  1. tracé enregistré  2. coordonnées enregistrées  3. recherche des villes
  Future<Itineraire?> itineraireDuTrajet(Trajet t) async {
    LatLng? a = t.latDepart != null && t.lngDepart != null
        ? LatLng(t.latDepart!, t.lngDepart!)
        : null;
    LatLng? b = t.latArrivee != null && t.lngArrivee != null
        ? LatLng(t.latArrivee!, t.lngArrivee!)
        : null;

    if (a != null && b != null && t.itineraire.isNotEmpty) {
      final pts = decoderPolyline(t.itineraire);
      if (pts.length >= 2) {
        return Itineraire(
          depart: a,
          arrivee: b,
          points: pts,
          distanceKm: t.distanceKm,
          dureeMinutes: t.dureeMinutes,
        );
      }
    }

    // Anciens trajets sans coordonnées : on cherche l'adresse puis la ville
    a ??= await _localiser(t.adresseDepart, t.villeDepart);
    b ??= await _localiser(t.adresseArrivee, t.villeArrivee);
    if (a == null || b == null) return null;
    return itineraire(a, b);
  }

  Future<LatLng?> _localiser(String adresse, String ville) async {
    if (adresse.trim().isNotEmpty) {
      final r = await rechercher('$adresse $ville');
      if (r.isNotEmpty) return LatLng(r.first.lat, r.first.lng);
    }
    final r = await rechercher(ville);
    return r.isEmpty ? null : LatLng(r.first.lat, r.first.lng);
  }

  // ============================================================
  // 5. LIEUX RÉCENTS ET ENREGISTRÉS (SQLite)
  // ============================================================

  Future<List<Lieu>> lieuxRecents() async {
    try {
      return await TrajetDatabase.instance.lieuxRecents();
    } catch (e) {
      debugPrint('CarteService : lieux récents indisponibles : $e');
      return [];
    }
  }

  Future<List<Lieu>> lieuxEnregistres() async {
    try {
      return await TrajetDatabase.instance.lieuxEnregistres();
    } catch (e) {
      debugPrint('CarteService : lieux enregistrés indisponibles : $e');
      return [];
    }
  }

  Future<void> memoriser(Lieu lieu) async {
    try {
      await TrajetDatabase.instance.memoriserLieu(lieu);
    } catch (e) {
      debugPrint('CarteService : impossible de mémoriser le lieu : $e');
    }
  }

  Future<void> basculerEnregistre(Lieu lieu) async {
    try {
      await TrajetDatabase.instance.basculerLieuEnregistre(lieu);
    } catch (e) {
      debugPrint('CarteService : impossible d’enregistrer le lieu : $e');
    }
  }

  // ============================================================
  // OUTILS
  // ============================================================

  Future<dynamic> _getJson(Uri uri) async {
    try {
      final res = await http.get(uri, headers: _entetes).timeout(_delaiReseau);
      if (res.statusCode != 200) {
        debugPrint('CarteService : ${uri.host} a répondu ${res.statusCode}');
        return null;
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint('CarteService : erreur réseau (${uri.host}) : $e');
      return null;
    }
  }

  /// Convertit un résultat Photon (GeoJSON) en Lieu
  Lieu? _lieuPhoton(dynamic f) {
    try {
      final coords = (f['geometry'] as Map)['coordinates'] as List;
      final p = (f['properties'] as Map).cast<String, dynamic>();

      final rue = _joindre([_texte(p, 'housenumber'), _texte(p, 'street')], '',
          separateur: ' ');
      final nomOsm = _texte(p, 'name');
      final ville = _premier(p, ['city', 'town', 'village', 'county', 'state']);
      final quartier = _premier(p, ['district', 'locality']);
      final nom = nomOsm.isNotEmpty
          ? nomOsm
          : (rue.isNotEmpty ? rue : (quartier.isNotEmpty ? quartier : ville));
      if (nom.isEmpty) return null;

      return Lieu(
        nom: nom,
        adresse: _joindre([if (nomOsm.isNotEmpty) rue, quartier, ville], nom),
        ville: ville,
        lat: (coords[1] as num).toDouble(),
        lng: (coords[0] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _texte(Map<String, dynamic> m, String cle) {
    final v = m[cle];
    return v is String ? v.trim() : '';
  }

  static String _premier(Map<String, dynamic> m, List<String> cles) {
    for (final c in cles) {
      final v = _texte(m, c);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// Joint les morceaux non vides, sans doublon et sans répéter [exclure]
  static String _joindre(List<String> morceaux, String exclure,
      {String separateur = ', '}) {
    final vus = <String>{};
    return morceaux
        .where((m) => m.isNotEmpty && m != exclure && vus.add(m))
        .join(separateur);
  }
}

// ============================================================
// POLYLINE ENCODÉE (format Google, précision 1e-5)
// Permet d'enregistrer le tracé de la route dans une colonne TEXT.
// ============================================================

/// Réduit le tracé à [max] points environ (pour l'enregistrement)
List<LatLng> simplifierTrace(List<LatLng> points, {int max = 300}) {
  if (points.length <= max) return points;
  final pas = (points.length / max).ceil();
  return [
    for (var i = 0; i < points.length; i += pas) points[i],
    if ((points.length - 1) % pas != 0) points.last,
  ];
}

String encoderPolyline(List<LatLng> points) {
  final sb = StringBuffer();
  var latPrec = 0, lngPrec = 0;
  for (final p in points) {
    final lat = (p.latitude * 1e5).round();
    final lng = (p.longitude * 1e5).round();
    _encoderValeur(lat - latPrec, sb);
    _encoderValeur(lng - lngPrec, sb);
    latPrec = lat;
    lngPrec = lng;
  }
  return sb.toString();
}

void _encoderValeur(int valeur, StringBuffer sb) {
  var v = valeur < 0 ? ~(valeur << 1) : (valeur << 1);
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}

List<LatLng> decoderPolyline(String code) {
  final points = <LatLng>[];
  var i = 0, lat = 0, lng = 0;
  try {
    while (i < code.length) {
      for (var k = 0; k < 2; k++) {
        var decalage = 0, resultat = 0, b = 0;
        do {
          b = code.codeUnitAt(i++) - 63;
          resultat |= (b & 0x1f) << decalage;
          decalage += 5;
        } while (b >= 0x20);
        final delta = (resultat & 1) != 0 ? ~(resultat >> 1) : (resultat >> 1);
        if (k == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
  } catch (_) {
    // Chaîne abîmée : on garde les points déjà lus
  }
  return points;
}
