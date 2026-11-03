// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/evaluation_trajet.dart
//  Évaluations après le trajet :
//   - ouvrirEvaluations : noter les participants d'un trajet terminé
//     (étoiles, qualités en un geste, commentaire facultatif) ;
//   - afficherAvisRecus : les avis reçus par l'utilisateur ;
//   - EtoilesNote : affichage d'une note en étoiles.
//  Les règles sont dans services/discussion_service.dart.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/discussion_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';

const Color _ambre = Color(0xFFF5A623);

const List<String> _libellesNote = [
  'Très décevant',
  'Décevant',
  'Correct',
  'Bien',
  'Excellent',
];

/// Qualités proposées en un geste selon la personne notée
const List<String> _qualitesConducteur = [
  'Ponctuel',
  'Conduite sûre',
  'Voiture propre',
  'Sympathique',
];
const List<String> _qualitesPassager = [
  'Ponctuel',
  'Respectueux',
  'Sympathique',
  'Bonne communication',
];

class EtoilesNote extends StatelessWidget {
  final double note;
  final double taille;
  const EtoilesNote({super.key, required this.note, this.taille = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            note >= i
                ? Icons.star_rounded
                : note >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: taille,
            color: _ambre,
          ),
      ],
    );
  }
}

/// Noter les participants d'un trajet terminé que l'utilisateur n'a
/// pas encore notés (directement s'il n'y en a qu'un)
Future<void> ouvrirEvaluations(BuildContext context, Trajet trajet) async {
  final cibles = DiscussionService.instance.aNoter(trajet, monId);
  if (cibles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vous avez déjà noté tous les participants.')));
    return;
  }
  if (cibles.length == 1) {
    await _noter(context, trajet, cibles.first);
    return;
  }

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => ListenableBuilder(
      listenable: DiscussionService.instance,
      builder: (sheetCtx, _) {
        final restants = DiscussionService.instance.aNoter(trajet, monId);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text('Notez vos passagers',
                      style: Theme.of(sheetCtx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                      '${trajet.villeDepart} → ${trajet.villeArrivee} · '
                      '${tDateCourte(trajet.dateDepart)}',
                      style: TextStyle(
                          color:
                              Theme.of(sheetCtx).colorScheme.onSurfaceVariant)),
                ),
                if (restants.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: Color(0xFF1B7F55)),
                    title: Text('Merci ! Tout le monde est noté.'),
                  ),
                for (final c in restants)
                  ListTile(
                    leading: CircleAvatar(child: Text(_initiale(c.nom))),
                    title: Text(c.nom),
                    trailing: FilledButton.tonal(
                      onPressed: () => _noter(sheetCtx, trajet, c),
                      child: const Text('Noter'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _initiale(String nom) =>
    nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();

Future<void> _noter(
    BuildContext context, Trajet trajet, CibleEvaluation cible) async {
  final messenger = ScaffoldMessenger.of(context);
  final envoye = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FeuilleNote(trajet: trajet, cible: cible),
  );
  if (envoye == true) {
    messenger.showSnackBar(SnackBar(
        content: Text('Merci ! Votre avis sur ${cible.nom} est enregistré.')));
  }
}

class _FeuilleNote extends StatefulWidget {
  final Trajet trajet;
  final CibleEvaluation cible;
  const _FeuilleNote({required this.trajet, required this.cible});

  @override
  State<_FeuilleNote> createState() => _FeuilleNoteState();
}

class _FeuilleNoteState extends State<_FeuilleNote> {
  int _note = 0;
  final Set<String> _qualites = {};
  final _commentaire = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    final texte = [..._qualites, _commentaire.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final erreur = await DiscussionService.instance.evaluer(
      widget.trajet,
      auteurId: monId,
      auteurNom: monNom,
      cibleId: widget.cible.id,
      note: _note,
      commentaire: texte,
    );
    if (!mounted) return;
    if (erreur != null) {
      setState(() => _envoi = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qualites =
        widget.cible.conducteur ? _qualitesConducteur : _qualitesPassager;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  widget.cible.conducteur ? cs.primary : cs.secondaryContainer,
              child: Text(_initiale(widget.cible.nom),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: widget.cible.conducteur
                          ? cs.onPrimary
                          : cs.onSecondaryContainer)),
            ),
            const SizedBox(height: 10),
            Text('Comment s’est passé le trajet avec ${widget.cible.nom} ?',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${widget.trajet.villeDepart} → ${widget.trajet.villeArrivee} · '
              '${tDateCourte(widget.trajet.dateDepart)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i étoile${i > 1 ? 's' : ''}',
                    iconSize: 38,
                    onPressed: () => setState(() => _note = i),
                    icon: Icon(
                      i <= _note
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _ambre,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 20,
              child: Text(_note == 0 ? '' : _libellesNote[_note - 1],
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _ambre)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final q in qualites)
                  FilterChip(
                    label: Text(q),
                    selected: _qualites.contains(q),
                    onSelected: (oui) => setState(
                        () => oui ? _qualites.add(q) : _qualites.remove(q)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentaire,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(longueurMaxCommentaire - 80),
              ],
              decoration: const InputDecoration(
                hintText: 'Un commentaire ? (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _note == 0 || _envoi ? null : _envoyer,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Envoyer mon avis'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les avis reçus par l'utilisateur (moyenne + détail)
void afficherAvisRecus(BuildContext context) {
  final service = DiscussionService.instance;
  final avis = service.evaluationsRecues(monId);
  final moyenne = service.noteMoyenne(monId);
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, defilement) => ListView(
        controller: defilement,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Text(moyenne.nombre == 0 ? '–' : moyenne.moyenne.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EtoilesNote(note: moyenne.moyenne, taille: 20),
                  Text('${moyenne.nombre} avis de passagers',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const Divider(height: 28),
          if (avis.isEmpty)
            Text('Vous n’avez pas encore reçu d’avis.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          for (final e in avis)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(_initiale(e.auteurNom)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.auteurNom,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            Text(tDateCourte(e.date),
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ),
                        EtoilesNote(note: e.note.toDouble()),
                        if (TrajetService.instance.parId(e.trajetId)
                            case final t?)
                          Text('${t.villeDepart} → ${t.villeArrivee}',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                        if (e.commentaire.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(e.commentaire),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
