// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/carte_itineraire.dart
//  Widgets de carte réutilisables (flutter_map + OpenStreetMap) :
//    - fondDeCarte()           : tuiles CARTO Voyager, sans clé API
//    - MarqueurLieu            : carré noir avec icône (départ / arrivée)
//    - PointPosition           : point bleu « vous êtes ici »
//    - CarteItineraire         : carte avec la route tracée
//    - ItinerairePleinEcranPage: la même carte en plein écran
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Fond de carte OpenStreetMap (style CARTO « Voyager », clair et lisible).
/// Gratuit, sans clé API. Pour une appli en production, prévoir un
/// fournisseur de tuiles avec compte (MapTiler, Stadia…).
TileLayer fondDeCarte(BuildContext context) => TileLayer(
      urlTemplate:
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'tn.esprit.covoiturage_etudiant',
      retinaMode: RetinaMode.isHighDensity(context),
    );

/// Mention obligatoire des sources de la carte
const Widget attributionCarte = SimpleAttributionWidget(
  source: Text('© OpenStreetMap contributors'),
);

/// Carré noir arrondi avec une icône blanche (comme inDrive)
class MarqueurLieu extends StatelessWidget {
  final IconData icone;
  final double taille;
  const MarqueurLieu({super.key, required this.icone, this.taille = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(taille * 0.28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icone, color: Colors.white, size: taille * 0.58),
    );
  }
}

/// Point bleu de la position GPS
class PointPosition extends StatelessWidget {
  const PointPosition({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x551A73E8), blurRadius: 10, spreadRadius: 6),
        ],
      ),
    );
  }
}

/// Carte affichant la route entre le départ et l'arrivée.
/// La caméra se cadre automatiquement sur l'itinéraire.
class CarteItineraire extends StatelessWidget {
  final LatLng depart;
  final LatLng arrivee;

  /// Points de la route ; si vide, on trace une ligne droite pointillée
  final List<LatLng> trace;

  /// false : carte figée (aperçu dans une page qui défile)
  final bool interactive;

  /// Ligne pointillée (itinéraire approximatif, sans réseau)
  final bool approximatif;

  final EdgeInsets marge;

  const CarteItineraire({
    super.key,
    required this.depart,
    required this.arrivee,
    this.trace = const [],
    this.interactive = false,
    this.approximatif = false,
    this.marge = const EdgeInsets.all(42),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawPoints = trace.length >= 2 ? trace : [depart, arrivee];
    final validPoints = rawPoints
        .where((p) => p.latitude >= -90 && p.latitude <= 90 && p.longitude >= -180 && p.longitude <= 180)
        .toList();
    final points = validPoints.isNotEmpty ? validPoints : [depart, arrivee];
    final limites = LatLngBounds.fromPoints([...points, depart, arrivee]);

    return FlutterMap(
      // Nouvelle clé = nouveau cadrage quand l'itinéraire change
      key: ValueKey(Object.hash(depart, arrivee, points.length, approximatif)),
      options: MapOptions(
        initialCameraFit:
            CameraFit.bounds(bounds: limites, padding: marge, maxZoom: 16),
        minZoom: 4,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        fondDeCarte(context),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 5,
              color: cs.primary,
              borderStrokeWidth: 2,
              borderColor: Colors.white,
              pattern: approximatif
                  ? StrokePattern.dashed(segments: const [12, 8])
                  : const StrokePattern.solid(),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: depart,
              width: 34,
              height: 34,
              child: const MarqueurLieu(icone: Icons.hail),
            ),
            Marker(
              point: arrivee,
              width: 34,
              height: 34,
              child: const MarqueurLieu(icone: Icons.flag),
            ),
          ],
        ),
        attributionCarte,
      ],
    );
  }
}

/// Itinéraire en plein écran (zoom et déplacement possibles)
class ItinerairePleinEcranPage extends StatelessWidget {
  final LatLng depart;
  final LatLng arrivee;
  final List<LatLng> trace;
  final bool approximatif;
  final String titre;
  final String? sousTitre;

  const ItinerairePleinEcranPage({
    super.key,
    required this.depart,
    required this.arrivee,
    this.trace = const [],
    this.approximatif = false,
    this.titre = 'Itinéraire',
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 17)),
            if (sousTitre != null)
              Text(sousTitre!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: CarteItineraire(
        depart: depart,
        arrivee: arrivee,
        trace: trace,
        approximatif: approximatif,
        interactive: true,
        marge: const EdgeInsets.all(60),
      ),
    );
  }
}

/// Aperçu cliquable d'un itinéraire (coins arrondis + bouton « agrandir »)
class ApercuItineraire extends StatelessWidget {
  final LatLng depart;
  final LatLng arrivee;
  final List<LatLng> trace;
  final bool approximatif;
  final double hauteur;
  final String titre;
  final String? sousTitre;

  const ApercuItineraire({
    super.key,
    required this.depart,
    required this.arrivee,
    this.trace = const [],
    this.approximatif = false,
    this.hauteur = 200,
    this.titre = 'Itinéraire',
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: hauteur,
        child: Stack(
          children: [
            Positioned.fill(
              child: CarteItineraire(
                depart: depart,
                arrivee: arrivee,
                trace: trace,
                approximatif: approximatif,
              ),
            ),
            // Toute la carte est cliquable -> plein écran
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItinerairePleinEcranPage(
                        depart: depart,
                        arrivee: arrivee,
                        trace: trace,
                        approximatif: approximatif,
                        titre: titre,
                        sousTitre: sousTitre,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.open_in_full,
                      size: 18, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
