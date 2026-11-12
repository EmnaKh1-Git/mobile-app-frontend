import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../user/services/user_service.dart';
import '../models/reclamation.dart';
import '../services/reclamation_service.dart';
import '../widgets/reclamation_widgets.dart';
import 'ajouter_reclamation_page.dart';
import 'reclamation_details_page.dart';
import 'reclamation_stats_page.dart';

export 'ajouter_reclamation_page.dart';
export 'reclamation_details_page.dart';

enum _Filtre { toutes, ouvertes, enRetard, resolues, rejetees }

enum _Tri { recentes, priorite, echeance }

class ReclamationPage extends StatefulWidget {
  const ReclamationPage({super.key});

  @override
  State<ReclamationPage> createState() => _ReclamationPageState();
}

class _ReclamationPageState extends State<ReclamationPage> {
  final TextEditingController _recherche = TextEditingController();
  _Filtre _filtre = _Filtre.toutes;
  _Tri _tri = _Tri.recentes;
  ReclamationType? _categorie;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  bool get _isAdmin => UserService.instance.currentUser?.isAdmin ?? false;

  /// Vrai quand la page est un onglet de l'accueil (pas de bouton retour) :
  /// la barre de navigation flottante recouvre alors le bas de l'écran.
  bool get _dansAccueil => !(ModalRoute.of(context)?.canPop ?? false);

  List<Reclamation> _appliquer(List<Reclamation> source) {
    final q = _recherche.text.trim().toLowerCase();
    final liste = source.where((r) {
      final okFiltre = switch (_filtre) {
        _Filtre.toutes => true,
        _Filtre.ouvertes => !r.status.estCloturee,
        _Filtre.enRetard => r.estEnRetard,
        _Filtre.resolues => r.status == ReclamationStatus.resolue,
        _Filtre.rejetees => r.status == ReclamationStatus.rejetee,
      };
      if (!okFiltre) return false;
      if (_categorie != null && r.type != _categorie) return false;
      if (q.isEmpty) return true;
      return r.sujet.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.trajet.toLowerCase().contains(q) ||
          r.typeLabel.toLowerCase().contains(q) ||
          (r.auteurNom ?? '').toLowerCase().contains(q);
    }).toList();

    switch (_tri) {
      case _Tri.recentes:
        liste.sort((a, b) => b.date.compareTo(a.date));
      case _Tri.priorite:
        liste.sort((a, b) {
          // Ouvertes d'abord, puis priorité décroissante, puis ancienneté.
          final c = (a.status.estCloturee ? 1 : 0).compareTo(
            b.status.estCloturee ? 1 : 0,
          );
          if (c != 0) return c;
          final p = b.priorite.index.compareTo(a.priorite.index);
          return p != 0 ? p : a.date.compareTo(b.date);
        });
      case _Tri.echeance:
        liste.sort((a, b) {
          final c = (a.status.estCloturee ? 1 : 0).compareTo(
            b.status.estCloturee ? 1 : 0,
          );
          return c != 0 ? c : a.echeance.compareTo(b.echeance);
        });
    }
    return liste;
  }

  void _nouvelle() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AjouterReclamationPage()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réclamations'),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Tableau de bord',
              icon: const Icon(Icons.insights_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReclamationStatsPage()),
              ),
            ),
          PopupMenuButton<_Tri>(
            tooltip: 'Trier',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _tri,
            onSelected: (t) => setState(() => _tri = t),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Tri.recentes, child: Text('Plus récentes')),
              PopupMenuItem(
                value: _Tri.priorite,
                child: Text('Priorité la plus haute'),
              ),
              PopupMenuItem(
                value: _Tri.echeance,
                child: Text('Échéance la plus proche'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ReclamationService.instance,
        builder: (context, _) {
          final service = ReclamationService.instance;
          final visibles = service.visiblesPour(
            UserService.instance.currentUser,
          );
          final stats = service.statistiques(visibles);
          final liste = _appliquer(visibles);

          return RefreshIndicator(
            onRefresh: service.rafraichir,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ResumeBandeau(stats: stats),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _recherche,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Rechercher (objet, trajet, catégorie…)',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _recherche.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(_recherche.clear),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final f in _Filtre.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(_libelleFiltre(f, stats)),
                                    selected: _filtre == f,
                                    onSelected: (_) =>
                                        setState(() => _filtre = f),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              DropdownButton<ReclamationType?>(
                                value: _categorie,
                                hint: const Text('Catégorie'),
                                underline: const SizedBox.shrink(),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Toutes catégories'),
                                  ),
                                  for (final t in ReclamationType.values)
                                    DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _categorie = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                if (liste.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune réclamation ne correspond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.texte2,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      _dansAccueil ? 180 : 96,
                    ),
                    sliver: SliverList.separated(
                      itemCount: liste.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _CarteReclamation(reclamation: liste[index]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      // La page est affichée dans l'accueil sous une barre de navigation
      // flottante (extendBody) : on remonte le bouton au-dessus d'elle, et on
      // le masque pendant la saisie pour ne pas couvrir le clavier.
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: _dansAccueil ? 80 : 0),
              child: FloatingActionButton.extended(
                heroTag: 'fab-nouvelle-reclamation',
                onPressed: _nouvelle,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle'),
              ),
            ),
    );
  }

  String _libelleFiltre(_Filtre f, ReclamationStats s) => switch (f) {
    _Filtre.toutes => 'Toutes (${s.total})',
    _Filtre.ouvertes => 'Ouvertes (${s.ouvertes})',
    _Filtre.enRetard => 'En retard (${s.enRetard})',
    _Filtre.resolues =>
      'Résolues (${s.parStatut[ReclamationStatus.resolue] ?? 0})',
    _Filtre.rejetees =>
      'Rejetées (${s.parStatut[ReclamationStatus.rejetee] ?? 0})',
  };
}

class _ResumeBandeau extends StatelessWidget {
  final ReclamationStats stats;

  const _ResumeBandeau({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget tuile(String valeur, String libelle, Color couleur, IconData icone) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icone, color: couleur, size: 20),
                const SizedBox(height: 4),
                Text(
                  valeur,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: couleur,
                  ),
                ),
                Text(
                  libelle,
                  style: const TextStyle(fontSize: 11, color: AppColors.texte2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tuile(
          '${stats.ouvertes}',
          'Ouvertes',
          const Color(0xFF0057B8),
          Icons.inbox_rounded,
        ),
        const SizedBox(width: 8),
        tuile(
          '${stats.enRetard}',
          'Hors délai',
          const Color(0xFFC62828),
          Icons.timer_off_outlined,
        ),
        const SizedBox(width: 8),
        tuile(
          '${(stats.tauxResolution * 100).round()} %',
          'Résolution',
          AppColors.primaire,
          Icons.task_alt_rounded,
        ),
      ],
    );
  }
}

class _CarteReclamation extends StatelessWidget {
  final Reclamation reclamation;

  const _CarteReclamation({required this.reclamation});

  @override
  Widget build(BuildContext context) {
    final r = reclamation;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReclamationDetailsPage(reclamation: r),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: r.estEnRetard
                ? const Color(0xFFC62828).withValues(alpha: 0.5)
                : AppColors.bordure,
            width: r.estEnRetard ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaireDoux,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icone(r.type), color: AppColors.primaire),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.sujet,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.auteurNom == null
                            ? r.typeLabel
                            : '${r.typeLabel} · ${r.auteurNom}',
                        style: const TextStyle(color: AppColors.texte2),
                      ),
                    ],
                  ),
                ),
                ReclamationStatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrioriteBadge(priorite: r.priorite, compact: true),
                if (r.responses.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.texte2,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${r.responses.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.texte2,
                        ),
                      ),
                    ],
                  ),
                if (r.imagePath != null ||
                    r.responses.any((m) => m.imagePath != null))
                  const Icon(
                    Icons.image_outlined,
                    size: 15,
                    color: AppColors.texte2,
                  ),
                if (r.satisfaction != null)
                  Text(
                    '★ ${r.satisfaction}/5',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE5A100),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.trajet,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaire,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy', 'fr_FR').format(r.date),
                  style: const TextStyle(color: AppColors.texte2, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(child: SlaIndicator(reclamation: r)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icone(ReclamationType type) => switch (type) {
    ReclamationType.retard => Icons.schedule_rounded,
    ReclamationType.conducteur => Icons.person_off_outlined,
    ReclamationType.vehicule => Icons.directions_car_outlined,
    ReclamationType.paiement => Icons.payments_outlined,
    ReclamationType.autre => Icons.report_problem_outlined,
  };
}
