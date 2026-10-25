// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/choix_sur_carte_page.dart
//  Choisir un point en déplaçant la carte (comme inDrive) :
//    - le repère reste au centre de l'écran
//    - à l'arrêt, le nom de la rue s'affiche dans la bulle
//    - bouton « recentrer » sur la position GPS
//    - « Terminé » renvoie le Lieu choisi (Navigator.pop)
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/lieu.dart';
import '../services/carte_service.dart';
import '../widgets/carte_itineraire.dart';

class ChoixSurCartePage extends StatefulWidget {
  /// Lieu affiché à l'ouverture (sinon la position GPS)
  final Lieu? initial;

  /// true : on choisit la destination (drapeau), false : le départ
  final bool estArrivee;

  const ChoixSurCartePage({super.key, this.initial, this.estArrivee = false});

  @override
  State<ChoixSurCartePage> createState() => _ChoixSurCartePageState();
}

class _ChoixSurCartePageState extends State<ChoixSurCartePage> {
  final _service = CarteService.instance;
  final _carte = MapController();

  late LatLng _centre;
  LatLng? _maPosition;
  Lieu? _lieu;
  bool _pret = false; // la carte est affichée (MapController utilisable)
  LatLng? _enAttente; // déplacement demandé avant que la carte soit prête
  bool _bouge = false; // l'utilisateur déplace la carte
  bool _chargement = false; // recherche de l'adresse en cours
  Timer? _attente;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _centre = init != null ? LatLng(init.lat, init.lng) : _service.positionConnue;
    _lieu = init;
    _chargement = init == null;
    _localiser(centrer: init == null);
  }

  @override
  void dispose() {
    _attente?.cancel();
    _carte.dispose();
    super.dispose();
  }

  /// Récupère la position GPS ; si [centrer], déplace la carte dessus
  Future<void> _localiser({required bool centrer}) async {
    final p = await _service.positionActuelle();
    if (!mounted) return;
    if (p != null) setState(() => _maPosition = p);
    if (!centrer) return;
    if (p == null && widget.initial == null && _lieu == null) {
      // Pas de GPS : on donne quand même l'adresse du centre (Tunis)
      _chercherAdresse(_centre);
      return;
    }
    if (p != null) {
      _deplacer(p);
      _chercherAdresse(p);
    }
  }

  void _deplacer(LatLng p) {
    if (_pret) {
      _carte.move(p, 16.5);
    } else {
      _enAttente = p;
    }
  }

  /// Appelé à chaque mouvement de la carte
  void _surMouvement(MapCamera camera, bool parGeste) {
    _centre = camera.center;
    if (!parGeste) return;
    if (!_bouge) {
      _bouge = true;
      // setState après l'image en cours (on peut être en pleine construction)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    // On attend que la carte soit immobile avant de chercher l'adresse
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 650),
        () => _chercherAdresse(_centre));
  }

  Future<void> _chercherAdresse(LatLng p) async {
    final n = ++_requete;
    setState(() {
      _bouge = false;
      _chargement = true;
    });
    final lieu = await _service.adresseDe(p);
    if (!mounted || n != _requete) return; // une recherche plus récente existe
    setState(() {
      _lieu = lieu;
      _chargement = false;
    });
  }

  Future<void> _recentrer() async {
    final p = await _service.positionActuelle();
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Position indisponible : activez la localisation du téléphone.')));
      return;
    }
    setState(() => _maPosition = p);
    _deplacer(p);
    _chercherAdresse(p);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final marges = MediaQuery.paddingOf(context);
    final peutValider = _lieu != null && !_bouge && !_chargement;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---- Carte ----
          FlutterMap(
            mapController: _carte,
            options: MapOptions(
              initialCenter: _centre,
              initialZoom: 16.5,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _pret = true;
                // La position GPS est peut-être arrivée avant la carte
                final p = _enAttente;
                if (p != null) {
                  _enAttente = null;
                  _carte.move(p, 16.5);
                }
              },
              onPositionChanged: _surMouvement,
            ),
            children: [
              fondDeCarte(context),
              if (_maPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _maPosition!,
                    width: 22,
                    height: 22,
                    child: const PointPosition(),
                  ),
                ]),
              attributionCarte,
            ],
          ),

          // ---- Repère fixe au centre ----
          IgnorePointer(
            child: Center(
              child: _Repere(
                texte: _lieu?.nom ?? '',
                chargement: _chargement || _bouge,
                leve: _bouge,
                icone: widget.estArrivee ? Icons.flag : Icons.hail,
              ),
            ),
          ),

          // ---- Retour ----
          Positioned(
            top: marges.top + 12,
            left: 16,
            child: _BoutonRond(
              icone: Icons.arrow_back,
              tooltip: 'Retour',
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ---- Consigne ----
          Positioned(
            top: marges.top + 18,
            left: 80,
            right: 16,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6)
                    ],
                  ),
                  child: Text(
                    widget.estArrivee
                        ? 'Déplacez la carte sur la destination'
                        : 'Déplacez la carte sur le point de départ',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),

          // ---- Recentrer sur ma position ----
          Positioned(
            right: 16,
            bottom: marges.bottom + 96,
            child: _BoutonRond(
              icone: Icons.near_me_outlined,
              tooltip: 'Ma position',
              onPressed: _recentrer,
            ),
          ),

          // ---- Terminé ----
          Positioned(
            left: 16,
            right: 16,
            bottom: marges.bottom + 16,
            child: SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: peutValider ? () => Navigator.pop(context, _lieu) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Terminé',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Repère : bulle avec le nom de la rue + carré noir + tige.
/// La pointe de la tige est exactement au centre de la carte.
class _Repere extends StatelessWidget {
  final String texte;
  final bool chargement;
  final bool leve;
  final IconData icone;

  const _Repere({
    required this.texte,
    required this.chargement,
    required this.leve,
    required this.icone,
  });

  static const double _hauteur = 112;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Point au sol (reste visible quand le repère est levé)
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
        ),
        // Le repère occupe la moitié haute : sa pointe tombe sur le centre
        Padding(
          padding: const EdgeInsets.only(bottom: _hauteur),
          child: SizedBox(
            height: _hauteur,
            child: AnimatedSlide(
              offset: Offset(0, leve ? -0.08 : 0),
              duration: const Duration(milliseconds: 150),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: chargement || texte.isEmpty
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            texte,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                    child: Icon(icone, color: Colors.white, size: 26),
                  ),
                  Container(width: 3, height: 14, color: Colors.black),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback onPressed;
  const _BoutonRond(
      {required this.icone, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 26,
        padding: const EdgeInsets.all(14),
        color: Colors.black87,
        icon: Icon(icone),
      ),
    );
  }
}
