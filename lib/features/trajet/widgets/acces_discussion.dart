// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/acces_discussion.dart
//  Accès à la discussion d'un trajet, avec son état :
//   - BoutonDiscussion : icône (cadenas avant l'ouverture, badge
//     des messages non lus ensuite) pour les cartes de Mes trajets ;
//   - CarteDiscussion : encart du détail du trajet.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/trajet.dart';
import '../screens/discussion_trajet_page.dart';
import '../services/discussion_service.dart';
import '../utils/trajet_format.dart';

void ouvrirDiscussion(BuildContext context, Trajet trajet) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DiscussionTrajetPage(trajet: trajet)),
  );
}

/// « S'ouvre demain à 06:30 », « 2 nouveaux messages », « Lecture seule »
String resumeDiscussion(Trajet t) {
  final service = DiscussionService.instance;
  switch (etatDiscussion(t)) {
    case EtatDiscussion.verrouillee:
      final o = ouvertureDiscussion(t);
      return 'S’ouvre ${tJourRelatif(o)} à ${tHeure(o)}';
    case EtatDiscussion.ouverte:
      final n = service.nonLus(t.id);
      return n == 0
          ? 'Ouverte · ${service.nbParticipants(t)} participants'
          : 'Ouverte · $n nouveau${n > 1 ? 'x' : ''} message${n > 1 ? 's' : ''}';
    case EtatDiscussion.lectureSeule:
      return 'Lecture seule';
  }
}

class BoutonDiscussion extends StatelessWidget {
  final Trajet trajet;
  const BoutonDiscussion({super.key, required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final etat = etatDiscussion(trajet);
    final nonLus = DiscussionService.instance.nonLus(trajet.id);

    return IconButton(
      tooltip: 'Discussion : ${resumeDiscussion(trajet)}',
      onPressed: () => ouvrirDiscussion(context, trajet),
      icon: Badge(
        isLabelVisible: etat == EtatDiscussion.ouverte && nonLus > 0,
        label: Text('$nonLus'),
        child: Icon(
          switch (etat) {
            EtatDiscussion.verrouillee => Icons.lock_clock_outlined,
            EtatDiscussion.ouverte => Icons.forum,
            EtatDiscussion.lectureSeule => Icons.forum_outlined,
          },
          color: etat == EtatDiscussion.ouverte ? cs.primary : null,
        ),
      ),
    );
  }
}

class CarteDiscussion extends StatelessWidget {
  final Trajet trajet;
  const CarteDiscussion({super.key, required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final etat = etatDiscussion(trajet);
    final ouverte = etat == EtatDiscussion.ouverte;
    final nonLus = DiscussionService.instance.nonLus(trajet.id);

    return Material(
      color: ouverte
          ? cs.primaryContainer.withValues(alpha: 0.55)
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ouvrirDiscussion(context, trajet),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ouverte ? cs.primary : cs.surface,
                child: Badge(
                  isLabelVisible: ouverte && nonLus > 0,
                  label: Text('$nonLus'),
                  child: Icon(
                    etat == EtatDiscussion.verrouillee
                        ? Icons.lock_clock_outlined
                        : Icons.forum_outlined,
                    color: ouverte ? cs.onPrimary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discussion du trajet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      etat == EtatDiscussion.verrouillee
                          ? '${resumeDiscussion(trajet)} (2 h avant le départ)'
                          : resumeDiscussion(trajet),
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
