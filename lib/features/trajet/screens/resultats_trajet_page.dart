// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/resultats_trajet_page.dart
//  Écran : résultats de recherche (tri, prix maximum, préférences)
//  Sans résultat, ou pour être prévenu des prochains trajets : alerte.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/lieu.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/trajet_card.dart';
import 'alertes_page.dart';
import 'detail_trajet_page.dart';

class ResultatsTrajetPage extends StatefulWidget {
  final String depart;
  final String arrivee;

  /// Lieux choisis sur la carte (recherche par proximité, 15 km)
  final Lieu? lieuDepart;
  final Lieu? lieuArrivee;
  final DateTime? date;
  final int places;

  const ResultatsTrajetPage({
    super.key,
    required this.depart,
    required this.arrivee,
    this.lieuDepart,
    this.lieuArrivee,
    this.date,
    this.places = 1,
  });

  @override
  State<ResultatsTrajetPage> createState() => _ResultatsTrajetPageState();
}

class _ResultatsTrajetPageState extends State<ResultatsTrajetPage> {
  String _tri = 'heure';
  double _prixMax = 100;

  // Préférences du passager
  bool _entreFilles = false;
  bool _nonFumeur = false;
  bool _bagages = false;
  bool _animaux = false;

  Future<void> _creerAlerte() => creerAlerteEtInformer(
        context,
        depart: widget.depart,
        arrivee: widget.arrivee,
        jour: widget.date,
        places: widget.places,
      );

  /// Puces des préférences, au-dessus des résultats
  Widget _preferences() {
    Widget puce(String libelle, IconData icone, bool choisi,
            ValueChanged<bool> onChanged) =>
        FilterChip(
          avatar: Icon(icone, size: 16),
          label: Text(libelle),
          selected: choisi,
          showCheckmark: false,
          onSelected: (v) => setState(() => onChanged(v)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final p in [
            puce('Entre filles', Icons.woman, _entreFilles,
                (v) => _entreFilles = v),
            puce('Non-fumeur', Icons.smoke_free, _nonFumeur,
                (v) => _nonFumeur = v),
            puce('Bagages', Icons.luggage, _bagages, (v) => _bagages = v),
            puce('Animaux', Icons.pets, _animaux, (v) => _animaux = v),
          ]) ...[
            p,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  static const Map<String, String> _tris = {
    'heure': 'Heure de départ',
    'prix': 'Prix croissant',
    'note': 'Meilleure note',
  };

  void _ouvrirFiltres() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trier par',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in _tris.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _tri == e.key,
                        onSelected: (_) {
                          setState(() => _tri = e.key);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Prix maximum : ${tPrix(_prixMax)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _prixMax,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: tPrix(_prixMax),
                  onChanged: (v) {
                    setState(() => _prixMax = v);
                    setSheet(() {});
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titre = [
      if (widget.depart.trim().isNotEmpty) widget.depart.trim(),
      if (widget.arrivee.trim().isNotEmpty) widget.arrivee.trim(),
    ].join(' → ');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre.isEmpty ? 'Tous les trajets' : titre,
                style: const TextStyle(fontSize: 17)),
            Text(
              '${widget.date == null ? "Toutes dates" : tDateCourte(widget.date!)}'
              ' • ${widget.places} passager(s)',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _ouvrirFiltres,
            icon: const Icon(Icons.tune),
            tooltip: 'Filtres',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: TrajetService.instance,
        builder: (context, _) {
          if (!TrajetService.instance.estCharge) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = TrajetService.instance.rechercher(
            depart: widget.depart,
            arrivee: widget.arrivee,
            lieuDepart: widget.lieuDepart,
            lieuArrivee: widget.lieuArrivee,
            date: widget.date,
            placesMin: widget.places,
            prixMax: _prixMax,
            nonFumeur: _nonFumeur,
            bagages: _bagages,
            animaux: _animaux,
            entreFilles: _entreFilles,
            tri: _tri,
          );

          if (liste.isEmpty) {
            return Column(
              children: [
                _preferences(),
                Expanded(
                  child: EtatVideTrajet(
                    icone: Icons.search_off,
                    titre: 'Aucun trajet trouvé',
                    message: 'Essayez une autre date ou une autre ville,\n'
                        'ou soyez prévenu dès qu’un trajet est publié.',
                    action: FilledButton.icon(
                      onPressed: _creerAlerte,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Créer une alerte'),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _preferences(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${liste.length} trajet(s) disponible(s)',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    TextButton.icon(
                      onPressed: _creerAlerte,
                      icon: const Icon(Icons.notifications_none, size: 18),
                      label: const Text('Alerte'),
                    ),
                  ],
                ),
              ),
              for (final t in liste)
                TrajetCard(
                  trajet: t,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailTrajetPage(trajet: t)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
