// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/publier_trajet_page.dart
//  Écran : publier un trajet en 3 étapes
//          OU modifier un trajet existant (même formulaire, pré-rempli)
//
//  PublierTrajetPage()                        -> nouveau trajet (INSERT)
//  PublierTrajetPage(trajetAModifier: t)      -> modification   (UPDATE)
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';

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

  @override
  void initState() {
    super.initState();
    // Mode modification : on pré-remplit le formulaire avec le trajet existant
    final t = widget.trajetAModifier;
    if (t != null) {
      _depart.text = t.villeDepart;
      _adresseDepart.text = t.adresseDepart;
      _arrivee.text = t.villeArrivee;
      _adresseArrivee.text = t.adresseArrivee;
      _distance.text = t.distanceKm > 0 ? t.distanceKm.toStringAsFixed(0) : '';
      _date = DateTime(t.dateDepart.year, t.dateDepart.month, t.dateDepart.day);
      _heure = TimeOfDay.fromDateTime(t.dateDepart);
      _duree = t.dureeMinutes.clamp(15, 480);
      _places = t.placesTotales.clamp(1, maCapacite);
      _prix = t.prixPlace.clamp(0.0, 100.0);
      _bagages = t.bagages;
      _fumeur = t.fumeur;
      _animaux = t.animaux;
      _reservationAuto = t.reservationAuto;
      _description.text = t.description;
    }
  }

  // Étape 1 : itinéraire
  final _depart = TextEditingController();
  final _adresseDepart = TextEditingController();
  final _arrivee = TextEditingController();
  final _adresseArrivee = TextEditingController();
  final _distance = TextEditingController();

  // Étape 2 : date, places, prix
  DateTime? _date;
  TimeOfDay? _heure;
  int _duree = 60;
  int _places = 2;
  double _prix = 10;

  // Étape 3 : options
  bool _bagages = true;
  bool _fumeur = false;
  bool _animaux = false;
  bool _reservationAuto = false;
  final _description = TextEditingController();

  @override
  void dispose() {
    _depart.dispose();
    _adresseDepart.dispose();
    _arrivee.dispose();
    _adresseArrivee.dispose();
    _distance.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime? get _dateHeure {
    if (_date == null || _heure == null) return null;
    return DateTime(
        _date!.year, _date!.month, _date!.day, _heure!.hour, _heure!.minute);
  }

  double get _km => double.tryParse(_distance.text.replaceAll(',', '.')) ?? 0;

  /// Prix conseillé : environ 0,25 DT par km
  double get _prixConseille => _km <= 0 ? 0 : (_km * 0.25).roundToDouble();

  bool _enCours = false;

  Future<void> _publier() async {
    if (_enCours) return;
    final dh = _dateHeure;
    if (dh == null) {
      _erreur('Veuillez choisir la date et l’heure de départ.');
      return;
    }

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
      villeDepart: _depart.text.trim(),
      adresseDepart: _adresseDepart.text.trim(),
      villeArrivee: _arrivee.text.trim(),
      adresseArrivee: _adresseArrivee.text.trim(),
      dateDepart: dh,
      dureeMinutes: _duree,
      distanceKm: _km,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const bordure = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _modeModification ? 'Modifier le trajet' : 'Publier un trajet'),
      ),
      body: Stepper(
        currentStep: _etape,
        onStepTapped: (i) => setState(() => _etape = i),
        onStepContinue: () {
          if (_etape < 2) {
            setState(() => _etape++);
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
            subtitle: _depart.text.isNotEmpty && _arrivee.text.isNotEmpty
                ? Text('${_depart.text} → ${_arrivee.text}')
                : null,
            isActive: _etape >= 0,
            state: _etape > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextField(
                  controller: _depart,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ville de départ *',
                    border: bordure,
                    prefixIcon: Icon(Icons.trip_origin),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _adresseDepart,
                  decoration: const InputDecoration(
                    labelText: 'Point de rendez-vous',
                    helperText: 'Ex : Place Barcelone, station Total…',
                    border: bordure,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _arrivee,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ville d’arrivée *',
                    border: bordure,
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _adresseArrivee,
                  decoration: const InputDecoration(
                    labelText: 'Point de dépose',
                    border: bordure,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _distance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Distance (km)',
                    border: bordure,
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
              ],
            ),
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
                          if (d != null) setState(() => _date = d);
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
                          if (t != null) setState(() => _heure = t);
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
                Slider(
                  value: _duree.toDouble(),
                  min: 15,
                  max: 480,
                  divisions: 31,
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
                  onSelectionChanged: (s) =>
                      setState(() => _places = s.first),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Prix par place',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(tPrix(_prix),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: cs.primary)),
                  ],
                ),
                Slider(
                  value: _prix,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: tPrix(_prix),
                  onChanged: (v) => setState(() => _prix = v.roundToDouble()),
                ),
                if (_prixConseille > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 18, color: cs.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prix conseillé : ${tPrix(_prixConseille)} '
                            '(${_km.toStringAsFixed(0)} km)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                              () => _prix = _prixConseille.clamp(0.0, 100.0)),
                          child: const Text('Appliquer'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
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
                        _ligne('Trajet',
                            '${_depart.text.isEmpty ? "?" : _depart.text} → ${_arrivee.text.isEmpty ? "?" : _arrivee.text}'),
                        _ligne(
                            'Départ',
                            _dateHeure == null
                                ? 'Non défini'
                                : '${tDateCourte(_dateHeure!)} à ${tHeure(_dateHeure!)}'),
                        _ligne('Places', '$_places'),
                        _ligne('Prix', '${tPrix(_prix)} / place'),
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

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
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
