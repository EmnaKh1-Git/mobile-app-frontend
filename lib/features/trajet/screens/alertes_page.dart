// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/alertes_page.dart
//  Écran : mes alertes de recherche. Dès qu'un autre conducteur
//  propose un trajet correspondant, une notification arrive dans la
//  cloche (NotificationService). Une alerte se crée ici, depuis les
//  résultats de recherche ou depuis l'assistant.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/notification_trajet.dart';
import '../../../models/trajet.dart';
import '../services/assistant_trajet.dart' show MomentJournee, MomentJourneeX;
import '../services/notification_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/trajet_card.dart';
import 'resultats_trajet_page.dart';

/// Crée l'alerte et affiche le résultat (message sans bouton : un
/// message avec bouton resterait affiché jusqu'à ce qu'on le touche).
/// Retourne null si l'alerte a été créée, sinon l'erreur.
Future<String?> creerAlerteEtInformer(
  BuildContext context, {
  String depart = '',
  String arrivee = '',
  DateTime? jour,
  int? heure,
  MomentJournee? moment,
  int places = 1,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final erreur = await NotificationService.instance.creerAlerte(
    depart: depart,
    arrivee: arrivee,
    jour: jour,
    heure: heure,
    moment: moment,
    places: places,
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(erreur ??
          'Alerte créée : vous serez prévenu dans les notifications '
              '(Notifications › Alertes de recherche).'),
    ));
  return erreur;
}

/// Trajets d'autres conducteurs, encore réservables, qui correspondent
/// déjà à l'alerte
List<Trajet> trajetsPourAlerte(AlerteTrajet a) => TrajetService.instance.tous
    .where((t) =>
        t.conducteurId != monId &&
        t.estReservable &&
        NotificationService.correspond(a, t))
    .toList();

/// « demain · le matin · 2 places »
String resumeAlerte(AlerteTrajet a) => [
      a.jour == null ? 'Toutes dates' : tJourRelatif(a.jour!),
      if (a.heure != null)
        'vers ${a.heure}h'
      else if (MomentJournee.values.asNameMap()[a.moment] case final m?)
        m.libelle.toLowerCase(),
      '${a.places} place${a.places > 1 ? 's' : ''}',
    ].join(' · ');

class AlertesPage extends StatelessWidget {
  const AlertesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes alertes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nouvelleAlerte(context),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Nouvelle alerte'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [NotificationService.instance, TrajetService.instance]),
        builder: (context, _) {
          final alertes = NotificationService.instance.alertes;
          if (alertes.isEmpty) {
            return const EtatVideTrajet(
              icone: Icons.notifications_off_outlined,
              titre: 'Aucune alerte',
              message: 'Créez une alerte : vous serez prévenu\n'
                  'dès qu’un trajet correspondant est publié.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Text(
                'Vous êtes prévenu dans la cloche dès qu’un conducteur '
                'publie un trajet correspondant.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final a in alertes) _CarteAlerte(alerte: a),
            ],
          );
        },
      ),
    );
  }

  Future<void> _nouvelleAlerte(BuildContext context) async {
    final res = await showModalBottomSheet<
        ({String depart, String arrivee, DateTime? jour, int places})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FormulaireAlerte(),
    );
    if (res == null || !context.mounted) return;
    await creerAlerteEtInformer(
      context,
      depart: res.depart,
      arrivee: res.arrivee,
      jour: res.jour,
      places: res.places,
    );
  }
}

class _CarteAlerte extends StatelessWidget {
  final AlerteTrajet alerte;
  const _CarteAlerte({required this.alerte});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = alerte;
    final trouves = trajetsPourAlerte(a);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.notifications_active_outlined,
                      size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.itineraire,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(resumeAlerte(a),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer l’alerte',
                  onPressed: () =>
                      NotificationService.instance.supprimerAlerte(a),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (trouves.isEmpty)
              Text('Aucun trajet pour l’instant : on vous préviendra.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
            else
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultatsTrajetPage(
                      depart: a.villeDepart,
                      arrivee: a.villeArrivee,
                      date: a.jour,
                      places: a.places,
                    ),
                  ),
                ),
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: Text('${trouves.length} trajet(s) disponible(s)'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Saisie d'une alerte : villes, date (facultative) et places
class _FormulaireAlerte extends StatefulWidget {
  const _FormulaireAlerte();

  @override
  State<_FormulaireAlerte> createState() => _FormulaireAlerteState();
}

class _FormulaireAlerteState extends State<_FormulaireAlerte> {
  final _depart = TextEditingController();
  final _arrivee = TextEditingController();
  DateTime? _jour;
  int _places = 1;

  @override
  void dispose() {
    _depart.dispose();
    _arrivee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bordure = OutlineInputBorder();
    final pret =
        _depart.text.trim().isNotEmpty || _arrivee.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvelle alerte',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _depart,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Départ',
                hintText: 'Ex : Tunis',
                prefixIcon: Icon(Icons.hail),
                border: bordure,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _arrivee,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Arrivée',
                hintText: 'Ex : Sousse',
                prefixIcon: Icon(Icons.flag_outlined),
                border: bordure,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _jour ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                );
                if (d != null) setState(() => _jour = d);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_jour == null
                  ? 'Toutes dates (facultatif)'
                  : '${tJourSemaine(_jour!)} ${tDateCourte(_jour!)}'),
            ),
            const SizedBox(height: 16),
            const Text('Places', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (var i = 1; i <= 4; i++)
                  ButtonSegment(value: i, label: Text('$i')),
              ],
              selected: {_places},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _places = s.first),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: pret
                  ? () => Navigator.pop(context, (
                        depart: _depart.text.trim(),
                        arrivee: _arrivee.text.trim(),
                        jour: _jour,
                        places: _places,
                      ))
                  : null,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Créer l’alerte'),
            ),
          ],
        ),
      ),
    );
  }
}
