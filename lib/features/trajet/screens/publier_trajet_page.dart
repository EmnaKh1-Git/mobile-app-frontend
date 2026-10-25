// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/publier_trajet_page.dart
//  Écran : publier un trajet en 3 étapes
//          OU modifier un trajet existant (même formulaire, pré-rempli)
//
//  PublierTrajetPage()                        -> nouveau trajet (INSERT)
//  PublierTrajetPage(trajetAModifier: t)      -> modification   (UPDATE)
//
//  Étape 1 « Itinéraire » (comme inDrive) : départ et arrivée choisis
//  par recherche d'adresse ou sur la carte ; la route est tracée et la
//  distance / la durée sont calculées automatiquement.
//  Étape 2 : prix par place avec − / + et prix recommandé (TarifService).
// ============================================================

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/lieu.dart';
import '../../../models/trajet.dart';
import '../services/carte_service.dart';
import '../services/tarif_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/carte_itineraire.dart';
import '../widgets/prix_propose.dart';
import 'choix_itineraire_page.dart';

class PublierTrajetPage extends StatefulWidget {
  /// Trajet à modifier ; null pour publier un nouveau trajet
  final Trajet? trajetAModifier;

  const PublierTrajetPage({super.key, this.trajetAModifier});

  @override
  State<PublierTrajetPage> createState() => _PublierTrajetPageState();
}

class _PublierTrajetPageState extends State<PublierTrajetPage> {
  int _etape = 0;

  bool get _modeModification => widget.trajetAModifier != null;

  // Étape 1 : itinéraire (carte)
  Lieu? _lieuDepart;
  Lieu? _lieuArrivee;
  Itineraire? _itineraire;
  bool _calculEnCours = false;
  int _calcul = 0; // numéro du dernier calcul (ignore les réponses périmées)

  // Étape 2 : date, places, prix
  DateTime? _date;
  TimeOfDay? _heure;
  int _duree = 60;
  int _places = 2;
  double _prix = 0;

  /// false : le prix suit le prix recommandé ; true : choisi à la main
  bool _prixModifie = false;

  // Étape 3 : options
  bool _bagages = true;
  bool _fumeur = false;
  bool _animaux = false;
  bool _reservationAuto = false;
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Mode modification : on pré-remplit le formulaire avec le trajet existant
    final t = widget.trajetAModifier;
    if (t != null) {
      _date = DateTime(t.dateDepart.year, t.dateDepart.month, t.dateDepart.day);
      _heure = TimeOfDay.fromDateTime(t.dateDepart);
      _duree = t.dureeMinutes.clamp(5, 600);
      _places = t.placesTotales.clamp(1, maCapacite);
      _prix = t.prixPlace;
      _prixModifie = true; // on garde le prix choisi par le conducteur
      _bagages = t.bagages;
      _fumeur = t.fumeur;
      _animaux = t.animaux;
      _reservationAuto = t.reservationAuto;
      _description.text = t.description;
      _calculEnCours = true;
      _chargerItineraireExistant(t);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  DateTime? get _dateHeure {
    if (_date == null || _heure == null) return null;
    return DateTime(
        _date!.year, _date!.month, _date!.day, _heure!.hour, _heure!.minute);
  }

  double get _km => _itineraire?.distanceKm ?? 0;

  EstimationPrix get _estimation => TarifService.estimer(
        distanceKm: _km,
        places: _places,
        depart: _dateHeure,
      );

  /// Le prix suit le prix recommandé tant que le conducteur ne l'a pas changé
  void _suivrePrixRecommande() {
    if (!_prixModifie) _prix = _estimation.prixIdeal;
  }

  // ------------------------------------------------------------
  // ITINÉRAIRE
  // ------------------------------------------------------------

  /// Modification : lieux et tracé du trajet existant
  Future<void> _chargerItineraireExistant(Trajet t) async {
    Lieu lieu(String adresse, String ville, double lat, double lng) => Lieu(
        nom: adresse.isNotEmpty ? adresse : ville,
        ville: ville,
        lat: lat,
        lng: lng);

    if (t.aCoordonnees) {
      _lieuDepart = lieu(t.adresseDepart, t.villeDepart, t.latDepart!, t.lngDepart!);
      _lieuArrivee =
          lieu(t.adresseArrivee, t.villeArrivee, t.latArrivee!, t.lngArrivee!);
    }

    final it = await CarteService.instance.itineraireDuTrajet(t);
    if (!mounted) return;
    setState(() {
      _calculEnCours = false;
      if (it == null) return;
      _itineraire = it;
      // Ancien trajet sans coordonnées : on garde les noms d'origine
      _lieuDepart ??= lieu(t.adresseDepart, t.villeDepart,
          it.depart.latitude, it.depart.longitude);
      _lieuArrivee ??= lieu(t.adresseArrivee, t.villeArrivee,
          it.arrivee.latitude, it.arrivee.longitude);
    });
  }

  Future<void> _choisirItineraire({bool arrivee = false}) async {
    final res = await Navigator.push<ItineraireChoisi>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChoixItinerairePage(
          depart: _lieuDepart,
          arrivee: _lieuArrivee,
          modifierArrivee: arrivee,
        ),
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      _lieuDepart = res.depart;
      _lieuArrivee = res.arrivee;
    });
    _calculerItineraire();
  }

  void _inverser() {
    setState(() {
      final tmp = _lieuDepart;
      _lieuDepart = _lieuArrivee;
      _lieuArrivee = tmp;
    });
    _calculerItineraire();
  }

  /// Route, distance et durée entre les deux lieux (OSRM)
  Future<void> _calculerItineraire() async {
    final a = _lieuDepart, b = _lieuArrivee;
    if (a == null || b == null) return;
    final n = ++_calcul;
    setState(() {
      _calculEnCours = true;
      _itineraire = null;
    });
    final it = await CarteService.instance
        .itineraire(LatLng(a.lat, a.lng), LatLng(b.lat, b.lng));
    if (!mounted || n != _calcul) return;
    setState(() {
      _calculEnCours = false;
      _itineraire = it;
      _duree = it.dureeMinutes.clamp(5, 600);
      _suivrePrixRecommande();
    });
  }

  // ------------------------------------------------------------
  // NAVIGATION ENTRE LES ÉTAPES
  // ------------------------------------------------------------

  /// Message d'erreur si l'étape [etape] n'est pas complète
  String? _erreurEtape(int etape) {
    if (etape == 0) {
      if (_lieuDepart == null || _lieuArrivee == null) {
        return 'Choisissez le point de départ et la destination.';
      }
      if (_itineraire == null) {
        return _calculEnCours
            ? 'Calcul de l’itinéraire en cours…'
            : 'Itinéraire non calculé : réessayez.';
      }
    }
    if (etape == 1 && _dateHeure == null) {
      return 'Veuillez choisir la date et l’heure de départ.';
    }
    return null;
  }

  void _allerA(int cible) {
    for (var e = 0; e < cible; e++) {
      final err = _erreurEtape(e);
      if (err != null) {
        _erreur(err);
        setState(() => _etape = e);
        return;
      }
    }
    setState(() => _etape = cible);
  }

  // ------------------------------------------------------------
  // PUBLICATION
  // ------------------------------------------------------------

  bool _enCours = false;

  Future<void> _publier() async {
    if (_enCours) return;
    for (var e = 0; e < 2; e++) {
      final err = _erreurEtape(e);
      if (err != null) {
        _erreur(err);
        setState(() => _etape = e);
        return;
      }
    }
    final dh = _dateHeure!;
    final d = _lieuDepart!, a = _lieuArrivee!, it = _itineraire!;

    final service = TrajetService.instance;
    final original = widget.trajetAModifier;
    final trajet = Trajet(
      // Nouveau trajet : id 0, SQLite attribue l'identifiant.
      // Modification : on garde l'id, le conducteur, les étapes et le statut.
      id: original?.id ?? 0,
      conducteurId: original?.conducteurId ?? monId,
      conducteurNom: original?.conducteurNom ?? monNom,
      conducteurNote: original?.conducteurNote ?? 5.0,
      vehicule: original?.vehicule ?? monVehicule,
      capaciteVehicule: original?.capaciteVehicule ?? maCapacite,
      etapes: original?.etapes,
      statut: original?.statut ?? StatutTrajet.publie,
      dateCreation: original?.dateCreation,
      // Ville (pour la recherche) + adresse précise (pour le rendez-vous)
      villeDepart: d.villeOuNom,
      adresseDepart: d.nom == d.villeOuNom ? '' : d.nom,
      villeArrivee: a.villeOuNom,
      adresseArrivee: a.nom == a.villeOuNom ? '' : a.nom,
      latDepart: d.lat,
      lngDepart: d.lng,
      latArrivee: a.lat,
      lngArrivee: a.lng,
      itineraire:
          it.approximatif ? '' : encoderPolyline(simplifierTrace(it.points)),
      dateDepart: dh,
      dureeMinutes: _duree,
      distanceKm: double.parse(it.distanceKm.toStringAsFixed(1)),
      placesTotales: _places,
      prixPlace: _prix,
      bagages: _bagages,
      fumeur: _fumeur,
      animaux: _animaux,
      reservationAuto: _reservationAuto,
      description: _description.text.trim(),
    );

    // Les règles de gestion sont vérifiées dans le service,
    // puis le trajet est enregistré dans SQLite
    setState(() => _enCours = true);
    final erreur = _modeModification
        ? await service.modifier(trajet) // UPDATE
        : await service.publier(trajet); // INSERT
    if (!mounted) return;
    setState(() => _enCours = false);
    if (erreur != null) {
      _erreur(erreur);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_modeModification
            ? 'Modifications enregistrées'
            : 'Trajet publié avec succès'),
      ),
    );
    Navigator.pop(context, true);
  }

  void _erreur(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
  }

  // ------------------------------------------------------------
  // INTERFACE
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const bordure = OutlineInputBorder();
    final estimation = _estimation;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _modeModification ? 'Modifier le trajet' : 'Publier un trajet'),
      ),
      body: Stepper(
        currentStep: _etape,
        onStepTapped: _allerA,
        onStepContinue: () {
          if (_etape < 2) {
            _allerA(_etape + 1);
          } else {
            _publier();
          }
        },
        onStepCancel: _etape == 0 ? null : () => setState(() => _etape--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: _enCours ? null : details.onStepContinue,
                child: Text(_etape < 2
                    ? 'Continuer'
                    : (_enCours
                        ? 'Enregistrement…'
                        : (_modeModification
                            ? 'Enregistrer les modifications'
                            : 'Publier le trajet'))),
              ),
              const SizedBox(width: 12),
              if (_etape > 0)
                TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Retour')),
            ],
          ),
        ),
        steps: [
          // ============ ÉTAPE 1 : ITINÉRAIRE ============
          Step(
            title: const Text('Itinéraire'),
            subtitle: _lieuDepart != null && _lieuArrivee != null
                ? Text(
                    '${_lieuDepart!.villeOuNom} → ${_lieuArrivee!.villeOuNom}')
                : null,
            isActive: _etape >= 0,
            state: _etape > 0 ? StepState.complete : StepState.indexed,
            content: _etapeItineraire(cs),
          ),

          // ============ ÉTAPE 2 : DATE, PLACES, PRIX ============
          Step(
            title: const Text('Date, places et prix'),
            subtitle: _dateHeure != null
                ? Text('${tDateCourte(_dateHeure!)} à ${tHeure(_dateHeure!)}')
                : null,
            isActive: _etape >= 1,
            state: _etape > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date ??
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 180)),
                          );
                          if (d != null) {
                            setState(() {
                              _date = d;
                              _suivrePrixRecommande();
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                            _date == null ? 'Date *' : tDateCourte(_date!)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime:
                                _heure ?? const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (t != null) {
                            setState(() {
                              _heure = t;
                              _suivrePrixRecommande();
                            });
                          }
                        },
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(_heure == null
                            ? 'Heure *'
                            : _heure!.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Durée estimée : ${tDuree(_duree)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_itineraire != null)
                  Text(
                    'Calculée d’après l’itinéraire '
                    '(${tDuree(_itineraire!.dureeMinutes)}) — ajustable',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                Slider(
                  value: _duree.toDouble().clamp(5.0, 600.0),
                  min: 5,
                  max: 600,
                  divisions: 119,
                  label: tDuree(_duree),
                  onChanged: (v) => setState(() => _duree = v.round()),
                ),
                const SizedBox(height: 8),
                const Text('Places proposées (max $maCapacite)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (int i = 1; i <= maCapacite; i++)
                      ButtonSegment(value: i, label: Text('$i')),
                  ],
                  selected: {_places},
                  onSelectionChanged: (s) => setState(() {
                    _places = s.first;
                    _suivrePrixRecommande();
                  }),
                ),
                const SizedBox(height: 20),
                const Text('Prix par place',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (_itineraire == null)
                  const Text('Choisissez d’abord l’itinéraire (étape 1).')
                else
                  PrixPropose(
                    prix: _prix,
                    estimation: estimation,
                    onChanged: (v) => setState(() {
                      _prix = v;
                      _prixModifie = v != estimation.prixIdeal;
                    }),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Gain estimé si complet : ${tPrix(_prix * _places)}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // ============ ÉTAPE 3 : OPTIONS ============
          Step(
            title: const Text('Options et publication'),
            isActive: _etape >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: _bagages,
                  onChanged: (v) => setState(() => _bagages = v),
                  title: const Text('Bagages acceptés'),
                  secondary: const Icon(Icons.luggage),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _fumeur,
                  onChanged: (v) => setState(() => _fumeur = v),
                  title: const Text('Fumeur autorisé'),
                  secondary: const Icon(Icons.smoking_rooms),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _animaux,
                  onChanged: (v) => setState(() => _animaux = v),
                  title: const Text('Animaux acceptés'),
                  secondary: const Icon(Icons.pets),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _reservationAuto,
                  onChanged: (v) => setState(() => _reservationAuto = v),
                  title: const Text('Réservation automatique'),
                  subtitle: const Text('Sans validation de ma part'),
                  secondary: const Icon(Icons.flash_on),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Message pour les passagers',
                    helperText: 'Ex : rendez-vous devant la station Total',
                    alignLabelWithHint: true,
                    border: bordure,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Récapitulatif',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _ligne('Départ', _lieuDepart?.libelleCourt ?? '?'),
                        _ligne('Arrivée', _lieuArrivee?.libelleCourt ?? '?'),
                        _ligne(
                            'Distance',
                            _itineraire == null
                                ? '?'
                                : '${_km.toStringAsFixed(1)} km • ${tDuree(_duree)}'),
                        _ligne(
                            'Date',
                            _dateHeure == null
                                ? 'Non définie'
                                : '${tDateCourte(_dateHeure!)} à ${tHeure(_dateHeure!)}'),
                        _ligne('Places', '$_places'),
                        _ligne('Prix',
                            _prix <= 0 ? 'Gratuit' : '${tPrix(_prix)} / place'),
                        _ligne('Véhicule', monVehicule),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contenu de l'étape 1 : départ / arrivée + carte + distance
  Widget _etapeItineraire(ColorScheme cs) {
    final d = _lieuDepart, a = _lieuArrivee, it = _itineraire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Carte « De / À » comme inDrive ----
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _LigneLieu(
                      icone: Icons.hail,
                      label: 'De',
                      lieu: d,
                      indication: 'Point de départ',
                      onTap: () => _choisirItineraire(),
                    ),
                    Divider(height: 1, indent: 52, color: cs.outlineVariant),
                    _LigneLieu(
                      icone: Icons.flag,
                      label: 'À',
                      lieu: a,
                      indication: 'Destination',
                      onTap: () => _choisirItineraire(arrivee: true),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Inverser départ et arrivée',
                onPressed: d != null && a != null ? _inverser : null,
                icon: const Icon(Icons.swap_vert),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- Carte avec la route ----
        if (d != null && a != null && it != null) ...[
          ApercuItineraire(
            depart: LatLng(d.lat, d.lng),
            arrivee: LatLng(a.lat, a.lng),
            trace: it.points,
            approximatif: it.approximatif,
            titre: '${d.villeOuNom} → ${a.villeOuNom}',
            sousTitre:
                '${it.distanceKm.toStringAsFixed(1)} km • ~${tDuree(it.dureeMinutes)}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.straighten, size: 18),
                label: Text('${it.distanceKm.toStringAsFixed(1)} km'),
              ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text('~${tDuree(it.dureeMinutes)}'),
              ),
              Chip(
                avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text('Prix conseillé ${tPrix(_estimation.prixIdeal)}'),
              ),
            ],
          ),
          if (it.approximatif)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pas de connexion : distance estimée à vol d’oiseau.',
                      style: TextStyle(fontSize: 12, color: cs.error),
                    ),
                  ),
                  TextButton(
                    onPressed: _calculerItineraire,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
        ] else if (_calculEnCours)
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Calcul de l’itinéraire…'),
              ],
            ),
          )
        else
          // ---- Aucun itinéraire encore ----
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _choisirItineraire(arrivee: d != null),
            child: Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: cs.primary),
                  const SizedBox(height: 8),
                  const Text('Indiquez votre itinéraire',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('La route, la distance et le prix seront calculés',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(label, style: const TextStyle(fontSize: 13))),
            Expanded(
              child: Text(valeur,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// Ligne « De » ou « À » de la carte d'itinéraire
class _LigneLieu extends StatelessWidget {
  final IconData icone;
  final String label;
  final Lieu? lieu;
  final String indication;
  final VoidCallback onTap;

  const _LigneLieu({
    required this.icone,
    required this.label,
    required this.lieu,
    required this.indication,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = lieu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            Icon(icone, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Text(
                    l?.nom ?? indication,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: l == null ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                  if (l != null && (l.adresse.isNotEmpty || l.ville.isNotEmpty))
                    Text(
                      l.adresse.isNotEmpty ? l.adresse : l.ville,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
