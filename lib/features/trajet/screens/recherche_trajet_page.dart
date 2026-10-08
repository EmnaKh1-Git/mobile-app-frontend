// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/recherche_trajet_page.dart
//  Écran : rechercher un trajet (+ prochains départs)
// ============================================================

import 'package:flutter/material.dart';

import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/trajet_card.dart';
import 'detail_trajet_page.dart';
import 'resultats_trajet_page.dart';

class RechercheTrajetPage extends StatefulWidget {
  const RechercheTrajetPage({super.key});

  @override
  State<RechercheTrajetPage> createState() => _RechercheTrajetPageState();
}

class _RechercheTrajetPageState extends State<RechercheTrajetPage> {
  final _depart = TextEditingController();
  final _arrivee = TextEditingController();
  DateTime? _date;
  int _places = 1;

  @override
  void dispose() {
    _depart.dispose();
    _arrivee.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _choisirPlaces() async {
    final n = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _ChoixPlaces(initial: _places, max: 4),
    );
    if (n != null) setState(() => _places = n);
  }

  void _permuter() {
    final tmp = _depart.text;
    _depart.text = _arrivee.text;
    _arrivee.text = tmp;
  }

  void _rechercher() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultatsTrajetPage(
          depart: _depart.text,
          arrivee: _arrivee.text,
          date: _date,
          places: _places,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un trajet')),
      body: ListenableBuilder(
        listenable: TrajetService.instance,
        builder: (context, _) {
          final suggestions = TrajetService.instance.rechercher();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _depart,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Départ',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.trip_origin),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _arrivee,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Arrivée',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.place),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _permuter,
                              icon: const Icon(Icons.swap_vert),
                              tooltip: 'Inverser',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _choisirDate,
                                icon: const Icon(Icons.calendar_today,
                                    size: 18),
                                label: Text(_date == null
                                    ? 'Date'
                                    : tDateCourte(_date!)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _choisirPlaces,
                                icon: const Icon(Icons.person, size: 18),
                                label: Text(
                                    '$_places place${_places > 1 ? 's' : ''}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _rechercher,
                            icon: const Icon(Icons.search),
                            label: const Text('Rechercher'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Prochains départs',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (!TrajetService.instance.estCharge)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (suggestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EtatVideTrajet(
                    icone: Icons.directions_car_outlined,
                    titre: 'Aucun départ prévu',
                    message: 'Revenez plus tard ou publiez votre trajet.',
                  ),
                )
              else
                for (final t in suggestions)
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

class _ChoixPlaces extends StatelessWidget {
  final int initial;
  final int max;
  const _ChoixPlaces({required this.initial, required this.max});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nombre de places',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          for (int i = 1; i <= max; i++)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('$i place${i > 1 ? 's' : ''}'),
              trailing: i == initial ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, i),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
