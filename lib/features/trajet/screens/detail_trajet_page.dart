// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/detail_trajet_page.dart
//  Écran : détail d'un trajet + réservation
//  En haut : la carte avec la route (touchez-la pour l'agrandir)
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/carte_service.dart';
import '../services/discussion_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/acces_discussion.dart';
import '../widgets/carte_itineraire.dart';
import '../widgets/evaluation_trajet.dart';
import '../widgets/presence_passager.dart';
import '../widgets/trajet_card.dart';
import 'publier_trajet_page.dart';

class DetailTrajetPage extends StatelessWidget {
  final Trajet trajet;
  const DetailTrajetPage({super.key, required this.trajet});

  Future<void> _reserver(BuildContext context, Trajet trajet) async {
    int nb = 1;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Réserver ce trajet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nombre de places'),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Retirer une place',
                        onPressed: nb > 1 ? () => setDlg(() => nb--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$nb', style: const TextStyle(fontSize: 18)),
                      IconButton(
                        tooltip: 'Ajouter une place',
                        onPressed: nb < trajet.placesDispo
                            ? () => setDlg(() => nb++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(tPrix(trajet.prixPlace * nb),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Confirmer')),
          ],
        ),
      ),
    );

    if (confirme != true) return;
    // Le module Réservation appellera cette méthode du module Trajets
    final ok = await TrajetService.instance.reserverPlaces(trajet.id, nb);
    if (!context.mounted) return;
    // On reste sur la page : la réservation et la discussion y apparaissent
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Réservation enregistrée : $nb place(s). '
                'Vous faites partie de la discussion du trajet.'
            : 'Plus assez de places disponibles'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On relit le trajet dans le service : la page se met à jour
    // après une modification, une réservation ou un nouveau message.
    return ListenableBuilder(
      listenable: Listenable.merge(
          [TrajetService.instance, DiscussionService.instance]),
      builder: (context, _) {
        final aJour = TrajetService.instance.parId(trajet.id);
        if (aJour == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détail du trajet')),
            body: const EtatVideTrajet(
              icone: Icons.delete_outline,
              titre: 'Trajet introuvable',
              message: 'Ce trajet a été supprimé.',
            ),
          );
        }
        return _page(context, aJour);
      },
    );
  }

  Widget _page(BuildContext context, Trajet trajet) {
    final cs = Theme.of(context).colorScheme;
    final estMonTrajet = trajet.conducteurId == monId;
    final discussions = DiscussionService.instance;
    final maReservation = discussions.reservationDe(trajet.id, monId);
    final participant = discussions.estParticipant(trajet, monId);

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du trajet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Carte de l'itinéraire ----
          _CarteDuTrajet(trajet: trajet),
          const SizedBox(height: 16),

          // ---- Date ----
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(tDateLongue(trajet.dateDepart),
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Itinéraire détaillé ----
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PointItineraire(
                    heure: tHeure(trajet.dateDepart),
                    ville: trajet.villeDepart,
                    adresse: trajet.adresseDepart,
                    icone: Icons.trip_origin,
                    couleur: cs.primary,
                  ),
                  for (final e in trajet.etapes)
                    _PointItineraire(
                      heure: '~',
                      ville: e.ville,
                      adresse: 'Étape • ${tPrix(e.prix)}',
                      icone: Icons.more_vert,
                      couleur: cs.outline,
                    ),
                  _PointItineraire(
                    heure: tHeure(trajet.dateArrivee),
                    ville: trajet.villeArrivee,
                    adresse: trajet.adresseArrivee,
                    icone: Icons.place,
                    couleur: cs.primary,
                    dernier: true,
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Info(
                          icone: Icons.schedule,
                          valeur: tDuree(trajet.dureeMinutes),
                          label: 'Durée'),
                      _Info(
                          icone: Icons.straighten,
                          valeur: '${trajet.distanceKm.toStringAsFixed(0)} km',
                          label: 'Distance'),
                      _Info(
                          icone: Icons.event_seat,
                          valeur:
                              '${trajet.placesDispo}/${trajet.placesTotales}',
                          label: 'Places'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Ma réservation (passager) ----
          if (maReservation != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22A06B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1B7F55), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous avez réservé ${maReservation.places} '
                      'place${maReservation.places > 1 ? 's' : ''} '
                      '· ${tPrix(maReservation.places * trajet.prixPlace)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B7F55)),
                    ),
                  ),
                  // Annulation possible jusqu'à 30 min avant le départ
                  if (discussions.motifRefusAnnulation(trajet, monId) == null)
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA3281A),
                          visualDensity: VisualDensity.compact),
                      onPressed: () =>
                          annulerReservationAvecConfirmation(context, trajet),
                      child: const Text('Annuler'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ---- Évaluation après le trajet ----
          if (discussions.aNoter(trajet, monId).isNotEmpty) ...[
            _CarteANoter(trajet: trajet),
            const SizedBox(height: 12),
          ],

          // ---- Discussion (conducteur et passagers) ----
          if (participant) ...[
            CarteDiscussion(trajet: trajet),
            const SizedBox(height: 16),
          ],

          // ---- Passagers (vus par le conducteur) ----
          if (estMonTrajet) ...[
            _ListePassagers(trajet: trajet),
            const SizedBox(height: 16),
          ],

          // ---- Conducteur ----
          Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Text(trajet.initialeConducteur,
                    style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              title: Text(trajet.conducteurNom,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('★ ${trajet.conducteurNote}  •  ${trajet.vehicule}',
                  style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Discussion du trajet',
                onPressed: participant
                    ? () => ouvrirDiscussion(context, trajet)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Réservez une place pour rejoindre '
                                  'la discussion du trajet.')),
                        ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Options ----
          Text('Options du trajet',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Option('Bagages', Icons.luggage, trajet.bagages),
              _Option('Fumeur', Icons.smoking_rooms, trajet.fumeur),
              _Option('Animaux', Icons.pets, trajet.animaux),
              _Option('Réservation auto', Icons.flash_on,
                  trajet.reservationAuto),
              if (trajet.entreFilles)
                const _Option('Entre filles', Icons.woman, true),
              if (trajet.estRegulier)
                const _Option('Trajet régulier', Icons.repeat, true),
            ],
          ),

          if (trajet.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Message du conducteur',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(trajet.description),
          ],
          const SizedBox(height: 24),
        ],
      ),

      // ---- Barre de réservation ----
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tPrix(trajet.prixPlace),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.primary)),
                  const Text('par place', style: TextStyle(fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (estMonTrajet) ...[
                // Conducteur : modifier ou supprimer son propre trajet
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await supprimerTrajetAvecConfirmation(
                        context, trajet);
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFA3281A)),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Color(0xFFA3281A))),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PublierTrajetPage(trajetAModifier: trajet),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: trajet.estReservable
                      ? () => _reserver(context, trajet)
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                      trajet.estReservable ? 'Réserver' : 'Indisponible'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte du trajet : tracé enregistré, sinon calculé à l'ouverture
class _CarteDuTrajet extends StatefulWidget {
  final Trajet trajet;
  const _CarteDuTrajet({required this.trajet});

  @override
  State<_CarteDuTrajet> createState() => _CarteDuTrajetState();
}

class _CarteDuTrajetState extends State<_CarteDuTrajet> {
  late Future<Itineraire?> _itineraire;

  @override
  void initState() {
    super.initState();
    _itineraire = CarteService.instance.itineraireDuTrajet(widget.trajet);
  }

  @override
  void didUpdateWidget(covariant _CarteDuTrajet ancien) {
    super.didUpdateWidget(ancien);
    final a = ancien.trajet, t = widget.trajet;
    // On ne recalcule que si l'itinéraire a changé (pas pour une réservation)
    if (a.itineraire != t.itineraire ||
        a.latDepart != t.latDepart ||
        a.lngDepart != t.lngDepart ||
        a.latArrivee != t.latArrivee ||
        a.lngArrivee != t.lngArrivee ||
        a.villeDepart != t.villeDepart ||
        a.villeArrivee != t.villeArrivee) {
      _itineraire = CarteService.instance.itineraireDuTrajet(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.trajet;
    return FutureBuilder<Itineraire?>(
      future: _itineraire,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(),
          );
        }
        final it = snap.data;
        if (it == null) {
          // Pas de réseau et pas de coordonnées : pas de carte
          return const SizedBox.shrink();
        }
        return ApercuItineraire(
          depart: it.depart,
          arrivee: it.arrivee,
          trace: it.points,
          approximatif: it.approximatif,
          hauteur: 190,
          titre: '${t.villeDepart} → ${t.villeArrivee}',
          sousTitre:
              '${(t.distanceKm > 0 ? t.distanceKm : it.distanceKm).toStringAsFixed(0)} km'
              ' • ${tDuree(t.dureeMinutes)}',
        );
      },
    );
  }
}

/// « Notez votre trajet » : le trajet est terminé et il reste des
/// participants à noter
class _CarteANoter extends StatelessWidget {
  final Trajet trajet;
  const _CarteANoter({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = DiscussionService.instance.aNoter(trajet, monId).length;
    final conducteur = trajet.conducteurId == monId;

    return Material(
      color: const Color(0xFFF5A623).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ouvrirEvaluations(context, trajet),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFF5A623),
                child: Icon(Icons.star_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notez votre trajet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      conducteur
                          ? '$n passager${n > 1 ? 's' : ''} à noter'
                          : 'Donnez votre avis sur ${trajet.conducteurNom}',
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

/// Passagers du trajet (nom, places, pointage), pour le conducteur
class _ListePassagers extends StatelessWidget {
  final Trajet trajet;
  const _ListePassagers({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = DiscussionService.instance;
    final passagers = service.passagers(trajet.id);
    final pointage = service.pointagePossible(trajet);
    final bilan = service.bilanPresence(trajet.id);
    final dejaPointe = bilan.presents + bilan.absents > 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Passagers', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  pointage || dejaPointe
                      ? '${bilan.presents}/${passagers.length} à bord'
                          '${bilan.absents > 0 ? ' · ${bilan.absents} absent${bilan.absents > 1 ? 's' : ''}' : ''}'
                      : '${trajet.placesReservees}/${trajet.placesTotales} places réservées',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (pointage && passagers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Au départ, pointez qui est monté à bord.',
                    style: TextStyle(fontSize: 12, color: cs.primary)),
              ),
            const SizedBox(height: 6),
            if (passagers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Aucun passager n’a encore réservé.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            for (final p in passagers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: cs.secondaryContainer,
                  child: Text(p.initiale,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSecondaryContainer)),
                ),
                title: Text(p.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${p.places} place${p.places > 1 ? 's' : ''} · '
                    'réservé ${tJourRelatif(p.dateReservation)}'),
                trailing: pointage
                    ? BoutonsPresence(trajet: trajet, passager: p)
                    : dejaPointe
                        ? PastillePresence(presence: p.presence)
                        : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _PointItineraire extends StatelessWidget {
  final String heure, ville, adresse;
  final IconData icone;
  final Color couleur;
  final bool dernier;

  const _PointItineraire({
    required this.heure,
    required this.ville,
    required this.adresse,
    required this.icone,
    required this.couleur,
    this.dernier = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 46,
            child: Text(heure,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Column(
          children: [
            Icon(icone, size: 16, color: couleur),
            if (!dernier)
              Container(
                  width: 2,
                  height: 34,
                  color: couleur.withValues(alpha: 0.35)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ville,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              if (adresse.isNotEmpty)
                Text(adresse,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (!dernier) const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icone;
  final String valeur, label;
  const _Info({required this.icone, required this.valeur, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(valeur, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icone;
  final bool actif;
  const _Option(this.label, this.icone, this.actif);

  @override
  Widget build(BuildContext context) {
    final gris = Theme.of(context).disabledColor;
    return Chip(
      avatar: Icon(icone, size: 16, color: actif ? Colors.green : gris),
      label: Text(actif ? label : '$label : non',
          style: TextStyle(fontSize: 12, color: actif ? null : gris)),
    );
  }
}
