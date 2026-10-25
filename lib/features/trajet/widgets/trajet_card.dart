// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/trajet_card.dart
//  Widgets réutilisables : TrajetCard, EtatVideTrajet
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/trajet.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';

class TrajetCard extends StatelessWidget {
  final Trajet trajet;
  final VoidCallback? onTap;

  /// true : affiche le statut (Mes trajets) ; false : les places libres (recherche)
  final bool afficherStatut;

  const TrajetCard({
    super.key,
    required this.trajet,
    this.onTap,
    this.afficherStatut = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Heures + itinéraire + prix ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text(tHeure(trajet.dateDepart),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(tDuree(trajet.dureeMinutes),
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(tHeure(trajet.dateArrivee),
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _LigneItineraire(couleur: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trajet.villeDepart,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 18),
                        Text(trajet.villeArrivee,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ],
                    ),
                  ),
                  Text(tPrix(trajet.prixPlace),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cs.primary)),
                ],
              ),
              const Divider(height: 22),
              // ---- Conducteur + places / statut ----
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      trajet.initialeConducteur,
                      style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trajet.conducteurNom,
                            style: const TextStyle(fontSize: 13)),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 12, color: Colors.amber),
                            Text(' ${trajet.conducteurNote}',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (afficherStatut)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: trajet.statut.couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(trajet.statut.libelle,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: trajet.statut.couleur)),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.event_seat,
                            size: 15, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${trajet.placesDispo} place(s)',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneItineraire extends StatelessWidget {
  final Color couleur;
  const _LigneItineraire({required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.circle_outlined, size: 12, color: couleur),
        Container(width: 2, height: 30, color: couleur.withValues(alpha: 0.4)),
        Icon(Icons.place, size: 14, color: couleur),
      ],
    );
  }
}

/// Demande confirmation puis supprime le trajet (SQLite).
/// Retourne true si le trajet a été supprimé.
Future<bool> supprimerTrajetAvecConfirmation(
    BuildContext context, Trajet trajet) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline, color: Color(0xFFA3281A)),
      title: const Text('Supprimer ce trajet ?'),
      content: Text(
        '${trajet.villeDepart} → ${trajet.villeArrivee}\n'
        '${tDateCourte(trajet.dateDepart)} à ${tHeure(trajet.dateDepart)}\n\n'
        'Cette action est définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: const Text('Garder'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC2361F)),
          onPressed: () => Navigator.pop(dctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirme != true) return false;

  final erreur = await TrajetService.instance.supprimer(trajet.id);
  messenger.showSnackBar(SnackBar(
    content: Text(erreur ?? 'Trajet supprimé'),
    backgroundColor: erreur == null ? null : Colors.red.shade700,
  ));
  return erreur == null;
}

/// Message affiché quand une liste est vide
class EtatVideTrajet extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String message;

  const EtatVideTrajet({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
