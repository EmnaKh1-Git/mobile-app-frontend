// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/detail_trajet_page.dart
//  Écran : détail d'un trajet + réservation
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Réservation enregistrée : $nb place(s)'
            : 'Plus assez de places disponibles'),
      ),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // On relit le trajet dans le service : la page se met à jour
    // après une modification ou une réservation.
    return ListenableBuilder(
      listenable: TrajetService.instance,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du trajet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                tooltip: 'Contacter (module Messagerie)',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ouverture de la messagerie…')),
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
