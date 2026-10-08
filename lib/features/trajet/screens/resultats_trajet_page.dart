// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/resultats_trajet_page.dart
//  Écran : résultats de recherche (tri + prix maximum)
// ============================================================

import 'package:flutter/material.dart';

import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/trajet_card.dart';
import 'detail_trajet_page.dart';

class ResultatsTrajetPage extends StatefulWidget {
  final String depart;
  final String arrivee;
  final DateTime? date;
  final int places;

  const ResultatsTrajetPage({
    super.key,
    required this.depart,
    required this.arrivee,
    this.date,
    this.places = 1,
  });

  @override
  State<ResultatsTrajetPage> createState() => _ResultatsTrajetPageState();
}

class _ResultatsTrajetPageState extends State<ResultatsTrajetPage> {
  String _tri = 'heure';
  double _prixMax = 100;

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
            date: widget.date,
            placesMin: widget.places,
            prixMax: _prixMax,
            tri: _tri,
          );

          if (liste.isEmpty) {
            return const EtatVideTrajet(
              icone: Icons.search_off,
              titre: 'Aucun trajet trouvé',
              message:
                  'Essayez une autre date ou une autre ville,\nou créez une alerte.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('${liste.length} trajet(s) disponible(s)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Alerte créée pour cette recherche')),
                        );
                      },
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
