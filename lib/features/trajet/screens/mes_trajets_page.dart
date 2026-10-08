// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/mes_trajets_page.dart
//  Écran : trajets publiés par l'utilisateur (À venir / Historique)
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/trajet_service.dart';
import '../widgets/trajet_card.dart';
import 'detail_trajet_page.dart';
import 'publier_trajet_page.dart';

class MesTrajetsPage extends StatelessWidget {
  const MesTrajetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes trajets'),
          bottom: const TabBar(
            tabs: [Tab(text: 'À venir'), Tab(text: 'Historique')],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListeMesTrajets(aVenir: true),
            _ListeMesTrajets(aVenir: false),
          ],
        ),
      ),
    );
  }
}

class _ListeMesTrajets extends StatelessWidget {
  final bool aVenir;
  const _ListeMesTrajets({required this.aVenir});

  void _actions(BuildContext context, Trajet t) {
    final service = TrajetService.instance;
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Démarrer le trajet'),
              enabled: t.statut == StatutTrajet.publie ||
                  t.statut == StatutTrajet.complet,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await service.demarrer(t.id);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Trajet démarré')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Terminer le trajet'),
              enabled: t.statut == StatutTrajet.enCours,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await service.terminer(t.id);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Trajet terminé')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Dupliquer (semaine suivante)'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final erreur = await service.dupliquer(t);
                messenger.showSnackBar(SnackBar(
                    content: Text(erreur ?? 'Trajet dupliqué et publié')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: const Text('Annuler le trajet',
                  style: TextStyle(color: Colors.red)),
              enabled: t.statut.estActif,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await service.annuler(t.id);
                messenger.showSnackBar(const SnackBar(
                    content: Text('Trajet annulé, les passagers seront prévenus')));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Chaque onglet se redessine dès que le service change
    return ListenableBuilder(
      listenable: TrajetService.instance,
      builder: (context, _) => _construireListe(context),
    );
  }

  Widget _construireListe(BuildContext context) {
    final service = TrajetService.instance;
    if (!service.estCharge) {
      return const Center(child: CircularProgressIndicator());
    }
    final liste =
        aVenir ? service.mesTrajets(monId, aVenir: true) : service.historique(monId);

    if (liste.isEmpty) {
      return EtatVideTrajet(
        icone: aVenir ? Icons.directions_car_outlined : Icons.history,
        titre: aVenir ? 'Aucun trajet à venir' : 'Historique vide',
        message: aVenir
            ? 'Publiez un trajet pour partager vos frais.'
            : 'Vos trajets terminés apparaîtront ici.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final t = liste[i];
        return Column(
          children: [
            TrajetCard(
              trajet: t,
              afficherStatut: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailTrajetPage(trajet: t)),
              ),
            ),
            // ---- Actions : Modifier / Supprimer / Gérer ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  if (aVenir) ...[
                    Text(
                      '${t.placesReservees}/${t.placesTotales} réservée(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublierTrajetPage(trajetAModifier: t),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFA3281A)),
                      onPressed: () => supprimerTrajetAvecConfirmation(context, t),
                    ),
                    TextButton.icon(
                      onPressed: () => _actions(context, t),
                      icon: const Icon(Icons.more_horiz, size: 18),
                      label: const Text('Gérer'),
                    ),
                  ] else ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => supprimerTrajetAvecConfirmation(context, t),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFA3281A)),
                      label: const Text('Supprimer de l’historique',
                          style: TextStyle(color: Color(0xFFA3281A))),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
