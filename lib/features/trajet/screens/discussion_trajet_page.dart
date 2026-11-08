// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/discussion_trajet_page.dart
//  Écran : discussion du trajet entre le conducteur et ses passagers.
//   - avant l'ouverture (2 h avant le départ) : écran verrouillé avec
//     l'heure d'ouverture, qui se déverrouille tout seul ;
//   - ouverte : messages + statuts rapides (« Je suis en route »…) ;
//   - trajet terminé ou annulé : lecture seule.
//  Les règles sont dans services/discussion_service.dart.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/discussion_trajet.dart';
import '../../../models/trajet.dart';
import '../services/discussion_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/presence_passager.dart';
import '../widgets/trajet_card.dart';

/// Statuts rapides proposés au conducteur et aux passagers
const List<(String, IconData)> _statutsConducteur = [
  ('Je suis en route', Icons.directions_car_outlined),
  ('J’ai 5 min de retard', Icons.schedule),
  ('J’ai 10 min de retard', Icons.more_time),
  ('Je suis au point de rendez-vous', Icons.place_outlined),
];

const List<(String, IconData)> _statutsPassager = [
  ('J’arrive', Icons.directions_walk),
  ('J’ai 5 min de retard', Icons.schedule),
  ('Je suis au point de rendez-vous', Icons.place_outlined),
  ('Merci, à tout à l’heure !', Icons.thumb_up_alt_outlined),
];

IconData _iconeStatut(String texte) {
  for (final (libelle, icone) in [..._statutsConducteur, ..._statutsPassager]) {
    if (libelle == texte) return icone;
  }
  return Icons.campaign_outlined;
}

class DiscussionTrajetPage extends StatefulWidget {
  final Trajet trajet;
  const DiscussionTrajetPage({super.key, required this.trajet});

  @override
  State<DiscussionTrajetPage> createState() => _DiscussionTrajetPageState();
}

class _DiscussionTrajetPageState extends State<DiscussionTrajetPage> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  Timer? _minuteur;
  int _nbAffiches = 0;

  @override
  void initState() {
    super.initState();
    // Toutes les 30 s : compte à rebours à jour, et la discussion
    // se déverrouille d'elle-même à l'heure d'ouverture
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _envoyer(Trajet t, String texte,
      {TypeMessageTrajet type = TypeMessageTrajet.texte}) async {
    final erreur = await DiscussionService.instance.envoyer(
      t,
      auteurId: monId,
      auteurNom: monNom,
      texte: texte,
      type: type,
    );
    if (!mounted) return;
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
    } else if (type == TypeMessageTrajet.texte) {
      _saisie.clear();
    }
  }

  /// Après l'affichage : message d'ouverture, messages lus, défilement
  void _apresAffichage(Trajet t, EtatDiscussion etat, int nbMessages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = DiscussionService.instance;
      if (etat != EtatDiscussion.verrouillee) {
        service.assurerOuverture(t);
        if (service.nonLus(t.id) > 0) service.marquerLu(t.id);
      }
      if (nbMessages != _nbAffiches && _defilement.hasClients) {
        final premier = _nbAffiches == 0;
        _nbAffiches = nbMessages;
        if (premier) {
          _defilement.jumpTo(_defilement.position.maxScrollExtent);
        } else {
          _defilement.animateTo(_defilement.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [TrajetService.instance, DiscussionService.instance]),
      builder: (context, _) {
        final service = DiscussionService.instance;
        final t = TrajetService.instance.parId(widget.trajet.id) ?? widget.trajet;

        if (!service.estParticipant(t, monId)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Discussion du trajet')),
            body: const EtatVideTrajet(
              icone: Icons.lock_outline,
              titre: 'Discussion réservée',
              message: 'Seuls le conducteur et les passagers ayant\n'
                  'réservé ce trajet peuvent y accéder.',
            ),
          );
        }

        final etat = etatDiscussion(t);
        final messages = service.messages(t.id);
        _apresAffichage(t, etat, messages.length);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.villeDepart} → ${t.villeArrivee}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  '${service.nbParticipants(t)} participants · départ '
                  '${tJourRelatif(t.dateDepart)} à ${tHeure(t.dateDepart)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Participants',
                onPressed: () => _afficherParticipants(context, t),
                icon: const Icon(Icons.group_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              _BandeauRendezVous(trajet: t, etat: etat),
              Expanded(
                child: etat == EtatDiscussion.verrouillee
                    ? _VueVerrouillee(trajet: t)
                    : ListView(
                        controller: _defilement,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        children: [
                          for (final m in messages)
                            _VueMessage(message: m, trajet: t),
                        ],
                      ),
              ),
              if (etat == EtatDiscussion.ouverte)
                _BarreSaisie(
                  controleur: _saisie,
                  statuts: t.conducteurId == monId
                      ? _statutsConducteur
                      : _statutsPassager,
                  onStatut: (s) =>
                      _envoyer(t, s, type: TypeMessageTrajet.statut),
                  onEnvoyer: () => _envoyer(t, _saisie.text),
                  indication: t.conducteurId == monId
                      ? 'Écrire à vos passagers…'
                      : 'Écrire au groupe…',
                )
              else if (etat == EtatDiscussion.lectureSeule)
                _BandeauLectureSeule(trajet: t),
            ],
          ),
        );
      },
    );
  }
}

void _afficherParticipants(BuildContext context, Trajet t) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Se met à jour pendant le pointage
    builder: (_) => ListenableBuilder(
      listenable: DiscussionService.instance,
      builder: (context, _) =>
          _listeParticipants(t, cs, DiscussionService.instance),
    ),
  );
}

Widget _listeParticipants(Trajet t, ColorScheme cs, DiscussionService service) {
  final passagers = service.passagers(t.id);
  // Le conducteur pointe ses passagers depuis cette liste
  final pointage = t.conducteurId == monId && service.pointagePossible(t);
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Participants (${passagers.length + 1})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: _Avatar(nom: t.conducteurNom, conducteur: true),
            title: Text(t.conducteurId == monId
                ? '${t.conducteurNom} (vous)'
                : t.conducteurNom),
            subtitle: Text('Conducteur · ${t.conducteurNote}/5 · ${t.vehicule}'),
          ),
          for (final p in passagers)
            ListTile(
              leading: _Avatar(nom: p.nom),
              title: Text(p.passagerId == monId ? '${p.nom} (vous)' : p.nom),
              subtitle: Text('Passager · ${p.places} place${p.places > 1 ? 's' : ''}'),
              trailing: pointage
                  ? BoutonsPresence(trajet: t, passager: p)
                  : p.presence == PresencePassager.inconnue
                      ? null
                      : PastillePresence(presence: p.presence),
            ),
          if (passagers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Aucun passager n’a encore réservé.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------
// WIDGETS
// ------------------------------------------------------------

/// Point de rendez-vous, heure de départ et compte à rebours
class _BandeauRendezVous extends StatelessWidget {
  final Trajet trajet;
  final EtatDiscussion etat;
  const _BandeauRendezVous({required this.trajet, required this.etat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final lieu = t.adresseDepart.isNotEmpty
        ? '${t.adresseDepart}, ${t.villeDepart}'
        : t.villeDepart;
    final etiquette = switch (t.statut) {
      StatutTrajet.enCours => 'En route',
      StatutTrajet.termine || StatutTrajet.annule => t.statut.libelle,
      _ => t.estPasse ? 'Départ passé' : tCompteARebours(t.dateDepart),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.place, size: 19, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Point de rendez-vous',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Text(lieu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tHeure(t.dateDepart),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
              Text(etiquette,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Avant l'ouverture : heure d'ouverture et participants
class _VueVerrouillee extends StatelessWidget {
  final Trajet trajet;
  const _VueVerrouillee({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ouverture = ouvertureDiscussion(trajet);
    final passagers = DiscussionService.instance.passagers(trajet.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_clock, size: 44, color: cs.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text('La discussion n’est pas encore ouverte',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Elle s’ouvrira automatiquement 2 h avant le départ, '
          '${tJourRelatif(ouverture)} à ${tHeure(ouverture)}. '
          'Vous pourrez alors échanger avec ${trajet.conducteurId == monId ? 'vos passagers' : 'le conducteur et les autres passagers'}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Ouverture ${tCompteARebours(ouverture)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: cs.primary)),
          ),
        ),
        const SizedBox(height: 28),
        Text('PARTICIPANTS',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PuceParticipant(nom: trajet.conducteurNom, conducteur: true),
            for (final p in passagers) _PuceParticipant(nom: p.nom),
          ],
        ),
        if (passagers.isEmpty) ...[
          const SizedBox(height: 8),
          Text('Aucun passager pour l’instant.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _PuceParticipant extends StatelessWidget {
  final String nom;
  final bool conducteur;
  const _PuceParticipant({required this.nom, this.conducteur = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(nom: nom, conducteur: conducteur, rayon: 13),
          const SizedBox(width: 6),
          Text(conducteur ? '$nom · conducteur' : nom,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String nom;
  final bool conducteur;
  final double rayon;
  const _Avatar({required this.nom, this.conducteur = false, this.rayon = 18});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: rayon,
      backgroundColor: conducteur ? cs.primary : cs.secondaryContainer,
      child: Text(
        nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: rayon * 0.85,
          fontWeight: FontWeight.w700,
          color: conducteur ? cs.onPrimary : cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _VueMessage extends StatelessWidget {
  final MessageTrajet message;
  final Trajet trajet;
  const _VueMessage({required this.message, required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = message;

    // ---- Événement du trajet : pastille centrée ----
    if (m.estSysteme) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              m.texte,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final moi = m.auteurId == monId;
    final conducteur = m.auteurId == trajet.conducteurId;
    final statut = m.type == TypeMessageTrajet.statut;
    final couleurTexte = moi ? cs.onPrimary : cs.onSurface;

    final bulle = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: moi
            ? cs.primary
            : statut
                ? cs.secondaryContainer
                : cs.surface,
        border: moi || statut
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(moi ? 18 : 4),
          bottomRight: Radius.circular(moi ? 4 : 18),
        ),
      ),
      child: statut
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconeStatut(m.texte),
                    size: 18,
                    color: moi ? cs.onPrimary : cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(m.texte,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: moi ? cs.onPrimary : cs.onSecondaryContainer)),
                ),
              ],
            )
          : Text(m.texte,
              style: TextStyle(color: couleurTexte, fontSize: 15, height: 1.3)),
    );

    final heure = Text(tHeure(m.date),
        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));

    if (moi) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [bulle, const SizedBox(height: 3), heure],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(nom: m.auteurNom, conducteur: conducteur, rayon: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.auteurNom,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    if (conducteur) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Conducteur',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                bulle,
                const SizedBox(height: 3),
                heure,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarreSaisie extends StatelessWidget {
  final TextEditingController controleur;
  final List<(String, IconData)> statuts;
  final ValueChanged<String> onStatut;
  final VoidCallback onEnvoyer;
  final String indication;
  const _BarreSaisie({
    required this.controleur,
    required this.statuts,
    required this.onStatut,
    required this.onEnvoyer,
    required this.indication,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Statuts rapides ----
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                itemCount: statuts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (libelle, icone) = statuts[i];
                  return ActionChip(
                    avatar: Icon(icone, size: 16, color: cs.primary),
                    label: Text(libelle),
                    labelStyle: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600),
                    backgroundColor: cs.surface,
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                    shape: const StadiumBorder(),
                    onPressed: () => onStatut(libelle),
                  );
                },
              ),
            ),
            // ---- Message libre ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controleur,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(longueurMaxMessage),
                      ],
                      onSubmitted: (_) => onEnvoyer(),
                      decoration: InputDecoration(
                        hintText: indication,
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controleur,
                    builder: (context, valeur, _) => IconButton.filled(
                      tooltip: 'Envoyer',
                      onPressed:
                          valeur.text.trim().isEmpty ? null : onEnvoyer,
                      icon: const Icon(Icons.send_rounded),
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
}

class _BandeauLectureSeule extends StatelessWidget {
  final Trajet trajet;
  const _BandeauLectureSeule({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trajet.statut == StatutTrajet.annule
                      ? 'Trajet annulé : la discussion est en lecture seule.'
                      : 'Trajet terminé : la discussion est en lecture seule.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
