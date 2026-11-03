// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/mes_trajets_page.dart
//  Écran : trajets publiés par l'utilisateur (À venir / Historique)
//  En-tête « tableau de bord » : trajets à venir, passagers, gains
//  prévus et compte à rebours jusqu'au prochain départ.
//  À venir : trajets groupés (En cours, Aujourd'hui, Demain…) avec
//  l'action utile du moment (Démarrer, Terminer, Modifier).
//  Réservés : trajets où l'utilisateur est passager.
//  Historique : bilan (gains, passagers, CO₂ évité), filtre par
//  statut et regroupement par mois.
//  Chaque carte donne accès à la discussion du trajet (ouverte 2 h
//  avant le départ), avec le nombre de messages non lus.
// ============================================================

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/trajet.dart';
import '../services/discussion_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/acces_discussion.dart';
import '../widgets/bouton_notifications.dart';
import '../widgets/evaluation_trajet.dart';
import '../widgets/impact_trajets.dart';
import '../widgets/options_trajet.dart';
import '../widgets/trajet_card.dart';
import 'detail_trajet_page.dart';
import 'publier_trajet_page.dart';
import 'recherche_trajet_page.dart';

const Color _rouge = Color(0xFFA3281A);
const Color _vert = Color(0xFF1B7F55);

/// Hauteur de la barre d'onglets sous le tableau de bord
const double _hauteurOnglets = 60;

class MesTrajetsPage extends StatelessWidget {
  const MesTrajetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLow,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _ouvrir(context, const PublierTrajetPage()),
          icon: const Icon(Icons.add),
          label: const Text('Publier un trajet'),
        ),
        // Les onglets se redessinent dès que le service change
        body: ListenableBuilder(
          listenable: Listenable.merge(
              [TrajetService.instance, DiscussionService.instance]),
          builder: (context, _) {
            final service = TrajetService.instance;
            final aVenir = service.mesTrajets(monId, aVenir: true);
            final historique = service.historique(monId);
            // Trajets d'autres conducteurs où j'ai réservé : encore actifs,
            // puis terminés (à noter), du plus récent au plus ancien
            final mesReservations = [
              for (final id in DiscussionService.instance.trajetsReserves(monId))
                ?service.parId(id),
            ];
            final reserves = mesReservations
                .where((t) => t.statut.estActif)
                .toList()
              ..sort((a, b) => a.dateDepart.compareTo(b.dateDepart));
            final reservesTermines = mesReservations
                .where((t) => t.statut == StatutTrajet.termine)
                .toList()
              ..sort((a, b) => b.dateDepart.compareTo(a.dateDepart));

            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    pinned: true,
                    expandedHeight: 300,
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    title: const Text('Mes trajets',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    actions: const [
                      BoutonNotifications(),
                      SizedBox(width: 8),
                    ],
                    // Le dégradé couvre tout l'en-tête ; le tableau de bord
                    // s'arrête au-dessus des onglets pour ne pas passer dessous
                    flexibleSpace: _FondDegrade(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(bottom: _hauteurOnglets),
                        child: FlexibleSpaceBar(
                          background: _TableauDeBord(aVenir: aVenir),
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(_hauteurOnglets),
                      child: _Onglets(
                        nbAVenir: aVenir.length,
                        nbReserves: reserves.length,
                        nbHistorique: historique.length,
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _OngletAVenir(trajets: aVenir, charge: service.estCharge),
                  _OngletReserves(
                    trajets: reserves,
                    termines: reservesTermines,
                    charge: service.estCharge,
                  ),
                  _OngletHistorique(
                      trajets: historique, charge: service.estCharge),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

void _ouvrir(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

/// Moins de 2 h avant le départ (ou départ passé) : on propose « Démarrer »
bool _departDansMoinsDe2h(Trajet t) =>
    t.dateDepart.difference(DateTime.now()).inHours < 2;

// ------------------------------------------------------------
// EN-TÊTE : TABLEAU DE BORD + ONGLETS
// ------------------------------------------------------------

/// Fond de l'en-tête : dégradé bleu + cercles décoratifs
class _FondDegrade extends StatelessWidget {
  final Widget child;
  const _FondDegrade({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, AppColors.primaireFonce],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(right: -60, top: -40, child: _Cercle(taille: 200)),
          const Positioned(left: -40, bottom: 30, child: _Cercle(taille: 120)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Chiffres clés + prochain départ (se replie avec l'en-tête)
class _TableauDeBord extends StatelessWidget {
  final List<Trajet> aVenir;
  const _TableauDeBord({required this.aVenir});

  @override
  Widget build(BuildContext context) {
    final passagers = aVenir.fold<int>(0, (s, t) => s + t.placesReservees);
    final gains =
        aVenir.fold<double>(0, (s, t) => s + t.placesReservees * t.prixPlace);
    final prochain = aVenir.isEmpty ? null : aVenir.first;

    // Placé sur toute la hauteur de l'en-tête déplié (onglets compris).
    // Avec une grande taille de texte, le contenu rétrécit au lieu de déborder.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
        16,
        _hauteurOnglets + 10,
      ),
      child: LayoutBuilder(
        builder: (context, contraintes) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: contraintes.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _contenu(passagers, gains, prochain),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenu(int passagers, double gains, Trajet? prochain) => [
          Row(
            children: [
              _TuileStat(
                icone: Icons.event_available,
                valeur: '${aVenir.length}',
                libelle: 'À venir',
              ),
              const SizedBox(width: 10),
              _TuileStat(
                icone: Icons.groups_2_outlined,
                valeur: '$passagers',
                libelle: 'Passagers',
              ),
              const SizedBox(width: 10),
              _TuileStat(
                icone: Icons.payments_outlined,
                valeur: tPrix(gains),
                libelle: 'Gains prévus',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BandeauProchain(trajet: prochain),
        ];
}

class _Cercle extends StatelessWidget {
  final double taille;
  const _Cercle({required this.taille});

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      );
}

class _TuileStat extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String libelle;
  const _TuileStat({
    required this.icone,
    required this.valeur,
    required this.libelle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: Colors.white, size: 18),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valeur,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            Text(libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// « Prochain départ dans 2 j 4 h · Tunis → Hammamet »
class _BandeauProchain extends StatelessWidget {
  final Trajet? trajet;
  const _BandeauProchain({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final String surtitre;
    final String titre;
    if (t == null) {
      surtitre = 'Aucun départ prévu';
      titre = 'Publiez un trajet pour partager vos frais';
    } else {
      surtitre = t.statut == StatutTrajet.enCours
          ? 'Trajet en cours'
          : t.estPasse
              ? 'Départ passé : pensez à le clôturer'
              : 'Prochain départ ${tCompteARebours(t.dateDepart)}';
      titre = '${t.villeDepart} → ${t.villeArrivee} · '
          '${tJourRelatif(t.dateDepart)} à ${tHeure(t.dateDepart)}';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: t == null
            ? () => _ouvrir(context, const PublierTrajetPage())
            : () => _ouvrir(context, DetailTrajetPage(trajet: t)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  t == null ? Icons.add_road : Icons.schedule,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surtitre,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                    Text(titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
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

class _Onglets extends StatelessWidget {
  final int nbAVenir;
  final int nbReserves;
  final int nbHistorique;
  const _Onglets({
    required this.nbAVenir,
    required this.nbReserves,
    required this.nbHistorique,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(10),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: cs.primary,
        unselectedLabelColor: Colors.white,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(height: 40, child: _LibelleOnglet('À venir', nbAVenir)),
          Tab(height: 40, child: _LibelleOnglet('Réservés', nbReserves)),
          Tab(height: 40, child: _LibelleOnglet('Historique', nbHistorique)),
        ],
      ),
    );
  }
}

class _LibelleOnglet extends StatelessWidget {
  final String texte;
  final int nombre;
  const _LibelleOnglet(this.texte, this.nombre);

  @override
  Widget build(BuildContext context) {
    // Couleur fournie par la TabBar (sélectionné / non sélectionné)
    final couleur = DefaultTextStyle.of(context).style.color ?? Colors.white;
    // Trois onglets sur un petit écran : le libellé rétrécit si besoin
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texte),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$nombre',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: couleur)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ONGLET « À VENIR »
// ------------------------------------------------------------

const List<String> _ordreSections = [
  'En cours',
  'À clôturer',
  'Aujourd’hui',
  'Demain',
  'Cette semaine',
  'Plus tard',
];

String _section(Trajet t) {
  if (t.statut == StatutTrajet.enCours) return 'En cours';
  if (t.estPasse) return 'À clôturer';
  final n = DateTime.now();
  final jours = DateTime(t.dateDepart.year, t.dateDepart.month, t.dateDepart.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (jours == 0) return 'Aujourd’hui';
  if (jours == 1) return 'Demain';
  if (jours < 7) return 'Cette semaine';
  return 'Plus tard';
}

class _OngletAVenir extends StatelessWidget {
  final List<Trajet> trajets;
  final bool charge;
  const _OngletAVenir({required this.trajets, required this.charge});

  @override
  Widget build(BuildContext context) {
    final groupes = <String, List<Trajet>>{};
    for (final t in trajets) {
      groupes.putIfAbsent(_section(t), () => []).add(t);
    }

    return _ListeOnglet(
      cle: 'aVenir',
      charge: charge,
      vide: trajets.isEmpty
          ? _EtatVide(
              icone: Icons.directions_car_outlined,
              titre: 'Aucun trajet à venir',
              message: 'Publiez un trajet pour partager vos frais\n'
                  'avec d’autres étudiants.',
              action: 'Publier un trajet',
              onAction: () => _ouvrir(context, const PublierTrajetPage()),
            )
          : null,
      enfants: [
        for (final s in _ordreSections)
          if (groupes[s] != null) ...[
            _TitreSection(titre: s, nombre: groupes[s]!.length),
            for (final t in groupes[s]!) _CarteMonTrajet(trajet: t),
          ],
      ],
    );
  }
}

// ------------------------------------------------------------
// ONGLET « RÉSERVÉS » (l'utilisateur est passager)
// ------------------------------------------------------------

class _OngletReserves extends StatelessWidget {
  final List<Trajet> trajets;

  /// Trajets réservés terminés : on peut y noter le conducteur
  final List<Trajet> termines;
  final bool charge;
  const _OngletReserves({
    required this.trajets,
    required this.termines,
    required this.charge,
  });

  @override
  Widget build(BuildContext context) {
    return _ListeOnglet(
      cle: 'reserves',
      charge: charge,
      vide: trajets.isEmpty && termines.isEmpty
          ? _EtatVide(
              icone: Icons.confirmation_number_outlined,
              titre: 'Aucune réservation',
              message: 'Les trajets que vous réservez comme\n'
                  'passager apparaîtront ici.',
              action: 'Rechercher un trajet',
              iconeAction: Icons.search,
              onAction: () => _ouvrir(context, const RechercheTrajetPage()),
            )
          : null,
      enfants: [
        if (trajets.isNotEmpty) ...[
          _TitreSection(titre: 'À venir', nombre: trajets.length),
          for (final t in trajets) _CarteReservation(trajet: t),
        ],
        if (termines.isNotEmpty) ...[
          _TitreSection(titre: 'Terminés', nombre: termines.length),
          for (final t in termines) _CarteReservation(trajet: t),
        ],
      ],
    );
  }
}

/// Trajet réservé : conducteur, places, prix payé et discussion
class _CarteReservation extends StatelessWidget {
  final Trajet trajet;
  const _CarteReservation({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final places =
        DiscussionService.instance.reservationDe(t.id, monId)?.places ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: () => _ouvrir(context, DetailTrajetPage(trajet: t)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BlocDate(date: t.dateDepart, couleur: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${t.villeDepart} → ${t.villeArrivee}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _PastilleStatut(statut: t.statut),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tHeure(t.dateDepart)} – ${tHeure(t.dateArrivee)}'
                          ' · ${tDuree(t.dureeMinutes)}',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        _LigneIcone(
                          icone: Icons.schedule,
                          texte: switch (t.statut) {
                            StatutTrajet.enCours => 'Trajet en cours',
                            StatutTrajet.termine =>
                              'Trajet terminé ${tJourRelatif(t.dateDepart)}',
                            _ => 'Départ ${tCompteARebours(t.dateDepart)}',
                          },
                          couleur: t.statut == StatutTrajet.termine
                              ? cs.onSurfaceVariant
                              : cs.primary,
                          gras: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: cs.primaryContainer,
                    child: Text(t.initialeConducteur,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.conducteurNom,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${t.conducteurNote}/5 · ${t.vehicule}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tPrix(places * t.prixPlace),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cs.primary)),
                      Text('$places place${places > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              if (t.statut == StatutTrajet.termine)
                _LigneAvisConducteur(trajet: t)
              else
                Row(
                  children: [
                    Expanded(
                      child: _LigneIcone(
                        icone: Icons.forum_outlined,
                        texte: 'Discussion · ${resumeDiscussion(t)}',
                        couleur: cs.onSurfaceVariant,
                      ),
                    ),
                    // Jusqu'à 30 min avant le départ
                    if (DiscussionService.instance
                            .motifRefusAnnulation(t, monId) ==
                        null)
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: _rouge,
                            visualDensity: VisualDensity.compact),
                        onPressed: () =>
                            annulerReservationAvecConfirmation(context, t),
                        child: const Text('Annuler'),
                      ),
                    BoutonDiscussion(trajet: t),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trajet réservé terminé : la note donnée au conducteur, ou « Noter »
class _LigneAvisConducteur extends StatelessWidget {
  final Trajet trajet;
  const _LigneAvisConducteur({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = DiscussionService.instance;
    final avis = service.evaluation(trajet.id, monId, trajet.conducteurId);
    final aNoter = service.aNoter(trajet, monId).isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: avis != null
              ? Row(
                  children: [
                    Text('Votre note  ',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    EtoilesNote(note: avis.note.toDouble()),
                  ],
                )
              : _LigneIcone(
                  icone: Icons.star_outline_rounded,
                  texte: aNoter
                      ? 'Comment était le trajet ?'
                      : 'Notation indisponible (absence)',
                  couleur: cs.onSurfaceVariant,
                ),
        ),
        if (aNoter)
          FilledButton.tonalIcon(
            style:
                FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => ouvrirEvaluations(context, trajet),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Noter'),
          ),
        if (service.messages(trajet.id).isNotEmpty)
          BoutonDiscussion(trajet: trajet),
      ],
    );
  }
}

// ------------------------------------------------------------
// ONGLET « HISTORIQUE »
// ------------------------------------------------------------

class _OngletHistorique extends StatefulWidget {
  final List<Trajet> trajets;
  final bool charge;
  const _OngletHistorique({required this.trajets, required this.charge});

  @override
  State<_OngletHistorique> createState() => _OngletHistoriqueState();
}

class _OngletHistoriqueState extends State<_OngletHistorique> {
  /// null : tous les statuts
  StatutTrajet? _filtre;

  @override
  Widget build(BuildContext context) {
    final tous = widget.trajets;
    final termines = tous.where((t) => t.statut == StatutTrajet.termine);
    final annules = tous.where((t) => t.statut == StatutTrajet.annule);
    final liste =
        _filtre == null ? tous : tous.where((t) => t.statut == _filtre).toList();

    // Regroupement par mois (la liste est déjà du plus récent au plus ancien)
    final parMois = <String, List<Trajet>>{};
    for (final t in liste) {
      parMois.putIfAbsent(tMoisAnnee(t.dateDepart), () => []).add(t);
    }

    return _ListeOnglet(
      cle: 'historique',
      charge: widget.charge,
      vide: tous.isEmpty
          ? const _EtatVide(
              icone: Icons.history,
              titre: 'Historique vide',
              message: 'Vos trajets terminés ou annulés\napparaîtront ici.',
            )
          : null,
      enfants: [
        _BilanHistorique(termines: termines.toList()),
        const SizedBox(height: 12),
        const CarteImpact(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            _Filtre('Tous', tous.length, _filtre == null,
                () => setState(() => _filtre = null)),
            _Filtre('Terminés', termines.length,
                _filtre == StatutTrajet.termine,
                () => setState(() => _filtre = StatutTrajet.termine)),
            _Filtre('Annulés', annules.length, _filtre == StatutTrajet.annule,
                () => setState(() => _filtre = StatutTrajet.annule)),
          ],
        ),
        if (liste.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Aucun trajet dans cette catégorie.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        for (final e in parMois.entries) ...[
          _TitreSection(titre: e.key, nombre: e.value.length),
          for (final t in e.value) _CarteMonTrajet(trajet: t, historique: true),
        ],
      ],
    );
  }
}

class _Filtre extends StatelessWidget {
  final String libelle;
  final int nombre;
  final bool choisi;
  final VoidCallback onTap;
  const _Filtre(this.libelle, this.nombre, this.choisi, this.onTap);

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text('$libelle ($nombre)'),
        selected: choisi,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      );
}

/// Bilan des trajets terminés : passagers, gains, note moyenne
/// (le CO₂ évité et les badges sont dans CarteImpact)
class _BilanHistorique extends StatelessWidget {
  final List<Trajet> termines;
  const _BilanHistorique({required this.termines});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final passagers = termines.fold<int>(0, (s, t) => s + t.placesReservees);
    final gains =
        termines.fold<double>(0, (s, t) => s + t.placesReservees * t.prixPlace);

    Widget chiffre(String valeur, String libelle) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valeur,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.primary)),
              ),
              const SizedBox(height: 2),
              Text(libelle,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        );
    final separateur =
        Container(width: 1, height: 34, color: cs.outlineVariant);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              chiffre('${termines.length}', 'Terminés'),
              separateur,
              chiffre('$passagers', 'Passagers'),
              separateur,
              chiffre(tPrix(gains), 'Gagnés'),
            ],
          ),
          const SizedBox(height: 12),
          const _LigneNoteMoyenne(),
        ],
      ),
    );
  }
}

/// Note moyenne reçue des passagers ; ouvre le détail des avis
class _LigneNoteMoyenne extends StatelessWidget {
  const _LigneNoteMoyenne();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = DiscussionService.instance.noteMoyenne(monId);

    return Material(
      color: const Color(0xFFF5A623).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => afficherAvisRecus(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              EtoilesNote(note: note.moyenne, taille: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.nombre == 0
                      ? 'Pas encore d’avis de passagers'
                      : '${note.moyenne.toStringAsFixed(1)}/5 · '
                          '${note.nombre} avis de passagers',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ÉLÉMENTS COMMUNS AUX DEUX ONGLETS
// ------------------------------------------------------------

/// Liste d'un onglet, placée sous l'en-tête repliable
class _ListeOnglet extends StatelessWidget {
  final String cle;
  final bool charge;
  final Widget? vide;
  final List<Widget> enfants;
  const _ListeOnglet({
    required this.cle,
    required this.charge,
    required this.vide,
    required this.enfants,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: PageStorageKey(cle),
      primary: true,
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        if (!charge)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (vide != null)
          SliverFillRemaining(hasScrollBody: false, child: vide)
        else
          SliverPadding(
            // En bas : place pour le bouton « Publier un trajet »
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            sliver: SliverList.list(children: enfants),
          ),
      ],
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String titre;
  final int nombre;
  const _TitreSection({required this.titre, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(titre.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$nombre',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String message;
  final String? action;
  final IconData iconeAction;
  final VoidCallback? onAction;
  const _EtatVide({
    required this.icone,
    required this.titre,
    required this.message,
    this.action,
    this.iconeAction = Icons.add,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 44, color: cs.primary),
          ),
          const SizedBox(height: 18),
          Text(titre,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          if (action != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(iconeAction),
              label: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// CARTE D'UN TRAJET
// ------------------------------------------------------------

class _CarteMonTrajet extends StatelessWidget {
  final Trajet trajet;
  final bool historique;
  const _CarteMonTrajet({required this.trajet, this.historique = false});

  bool get _modifiable =>
      trajet.statut == StatutTrajet.publie ||
      trajet.statut == StatutTrajet.complet;

  bool get _departProche => _departDansMoinsDe2h(trajet);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final details = [
      '${tHeure(t.dateDepart)} – ${tHeure(t.dateArrivee)}',
      tDuree(t.dureeMinutes),
      if (t.distanceKm > 0) '${t.distanceKm.round()} km',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: () => _ouvrir(context, DetailTrajetPage(trajet: t)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BlocDate(date: t.dateDepart, couleur: t.statut.couleur),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${t.villeDepart} → ${t.villeArrivee}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _PastilleStatut(statut: t.statut),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(details,
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        if (historique)
                          _LigneIcone(
                            icone: Icons.directions_car_outlined,
                            texte: t.vehicule,
                            couleur: cs.onSurfaceVariant,
                          )
                        else
                          _LigneIcone(
                            icone: t.statut == StatutTrajet.enCours
                                ? Icons.navigation_outlined
                                : Icons.schedule,
                            texte: t.statut == StatutTrajet.enCours
                                ? 'En route vers ${t.villeArrivee}'
                                : t.estPasse
                                    ? 'Départ passé : démarrez ou annulez'
                                    : 'Départ ${tCompteARebours(t.dateDepart)}',
                            couleur: t.estPasse &&
                                    t.statut != StatutTrajet.enCours
                                ? _rouge
                                : cs.primary,
                            gras: true,
                          ),
                        if (t.entreFilles || t.estRegulier) ...[
                          const SizedBox(height: 6),
                          PastillesOptions(trajet: t, toutes: false),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Occupation(trajet: t, historique: historique),
              const Divider(height: 20),
              historique
                  ? _ActionsHistorique(trajet: t)
                  : Row(
                      children: [
                        _ActionPrincipale(trajet: t),
                        const Spacer(),
                        // Si l'action principale est « Démarrer »,
                        // « Modifier » reste à portée de main
                        if (_modifiable && _departProche)
                          IconButton(
                            tooltip: 'Modifier',
                            onPressed: () => _ouvrir(context,
                                PublierTrajetPage(trajetAModifier: t)),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        BoutonDiscussion(trajet: t),
                        IconButton(
                          tooltip: 'Plus d’actions',
                          onPressed: () => _ouvrirActions(context, t),
                          icon: const Icon(Icons.more_horiz),
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

class _BlocDate extends StatelessWidget {
  final DateTime date;
  final Color couleur;
  const _BlocDate({required this.date, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(tJourSemaineCourt(date),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: couleur)),
          Text('${date.day}',
              style: TextStyle(
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: couleur)),
          Text(tMoisCourt(date),
              style: TextStyle(fontSize: 11, color: couleur)),
        ],
      ),
    );
  }
}

class _PastilleStatut extends StatelessWidget {
  final StatutTrajet statut;
  const _PastilleStatut({required this.statut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statut.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: statut.couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(statut.libelle,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statut.couleur)),
        ],
      ),
    );
  }
}

class _LigneIcone extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  final bool gras;
  const _LigneIcone({
    required this.icone,
    required this.texte,
    required this.couleur,
    this.gras = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 4),
        Expanded(
          child: Text(texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: couleur,
                  fontWeight: gras ? FontWeight.w600 : FontWeight.normal)),
        ),
      ],
    );
  }
}

/// Sièges réservés / libres + gains du trajet
class _Occupation extends StatelessWidget {
  final Trajet trajet;
  final bool historique;
  const _Occupation({required this.trajet, required this.historique});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trajet;
    final reservees = t.placesReservees;
    final annule = t.statut == StatutTrajet.annule;

    return Row(
      children: [
        for (var i = 0; i < t.placesTotales; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < reservees ? Icons.person : Icons.person_outline,
              size: 19,
              color: i < reservees && !annule ? cs.primary : cs.outlineVariant,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$reservees/${t.placesTotales} réservée${reservees > 1 ? 's' : ''}',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text('${tPrix(t.prixPlace)} / place',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              annule ? '—' : tPrix(reservees * t.prixPlace),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: annule ? cs.onSurfaceVariant : _vert),
            ),
            Text(
              annule
                  ? 'aucun gain'
                  : historique
                      ? 'gagnés'
                      : 'gains prévus',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

/// L'action utile du moment selon le statut et l'heure de départ
class _ActionPrincipale extends StatelessWidget {
  final Trajet trajet;
  const _ActionPrincipale({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final t = trajet;
    final service = TrajetService.instance;
    final messenger = ScaffoldMessenger.of(context);
    const compact = VisualDensity.compact;

    if (t.statut == StatutTrajet.enCours) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
            visualDensity: compact, backgroundColor: _vert),
        onPressed: () async {
          await service.terminer(t.id);
          messenger.showSnackBar(
              const SnackBar(content: Text('Trajet terminé, bravo !')));
        },
        icon: const Icon(Icons.flag, size: 18),
        label: const Text('Terminer'),
      );
    }

    final modifiable =
        t.statut == StatutTrajet.publie || t.statut == StatutTrajet.complet;
    if (modifiable && _departDansMoinsDe2h(t)) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(visualDensity: compact),
        onPressed: () async {
          await service.demarrer(t.id);
          messenger.showSnackBar(const SnackBar(
              content: Text('Trajet démarré, les passagers sont prévenus')));
        },
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Démarrer'),
      );
    }
    if (modifiable) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(visualDensity: compact),
        onPressed: () =>
            _ouvrir(context, PublierTrajetPage(trajetAModifier: t)),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Modifier'),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(visualDensity: compact),
      onPressed: () => _ouvrir(context, DetailTrajetPage(trajet: t)),
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: const Text('Voir le détail'),
    );
  }
}

class _ActionsHistorique extends StatelessWidget {
  final Trajet trajet;
  const _ActionsHistorique({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final aNoter = DiscussionService.instance.aNoter(trajet, monId).length;
    Future<void> republier() async {
      final erreur = await TrajetService.instance.dupliquer(trajet);
      messenger.showSnackBar(SnackBar(
        content: Text(erreur ?? 'Trajet republié la semaine prochaine'),
        backgroundColor: erreur == null ? null : Colors.red.shade700,
      ));
    }

    return Row(
      children: [
        // Passagers pas encore notés : « Noter » devient l'action principale
        if (aNoter > 0)
          FilledButton.tonalIcon(
            style:
                FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => ouvrirEvaluations(context, trajet),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: Text('Noter ($aNoter)'),
          )
        else
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: republier,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Republier'),
          ),
        const Spacer(),
        if (aNoter > 0)
          IconButton(
            tooltip: 'Republier la semaine prochaine',
            visualDensity: VisualDensity.compact,
            onPressed: republier,
            icon: const Icon(Icons.replay),
          ),
        // La discussion reste consultable (lecture seule) après le trajet
        if (DiscussionService.instance.messages(trajet.id).isNotEmpty)
          BoutonDiscussion(trajet: trajet),
        IconButton(
          tooltip: 'Supprimer de l’historique',
          visualDensity: VisualDensity.compact,
          onPressed: () => supprimerTrajetAvecConfirmation(context, trajet),
          icon: const Icon(Icons.delete_outline, color: _rouge),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// FEUILLE « PLUS D'ACTIONS »
// ------------------------------------------------------------

void _ouvrirActions(BuildContext context, Trajet t) {
  final service = TrajetService.instance;
  final messenger = ScaffoldMessenger.of(context);
  final cs = Theme.of(context).colorScheme;
  // Trajet régulier : ce trajet et les suivants de la série
  final suiteSerie = t.serieId == null
      ? const <Trajet>[]
      : service
          .prochainsDeSerie(t.serieId!)
          .where((x) => !x.dateDepart.isBefore(t.dateDepart))
          .toList();

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    // Hauteur selon le contenu (sinon les dernières actions sont coupées)
    isScrollControlled: true,
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${t.villeDepart} → ${t.villeArrivee}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${tJourRelatif(t.dateDepart)} à ${tHeure(t.dateDepart)}'
                  ' · ${t.placesReservees} passager(s)'),
              trailing: _PastilleStatut(statut: t.statut),
            ),
            const Divider(height: 8),
            _TuileAction(
              icone: Icons.play_circle_outline,
              couleur: cs.primary,
              titre: 'Démarrer le trajet',
              sousTitre: 'Prévient les passagers que vous êtes en route',
              actif: t.statut == StatutTrajet.publie ||
                  t.statut == StatutTrajet.complet,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await service.demarrer(t.id);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Trajet démarré')));
              },
            ),
            _TuileAction(
              icone: Icons.flag_outlined,
              couleur: _vert,
              titre: 'Terminer le trajet',
              sousTitre: 'Le trajet passera dans l’historique',
              actif: t.statut == StatutTrajet.enCours,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await service.terminer(t.id);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Trajet terminé')));
              },
            ),
            _TuileAction(
              icone: Icons.edit_outlined,
              couleur: cs.primary,
              titre: 'Modifier',
              sousTitre: 'Horaire, places, prix, itinéraire',
              actif: t.statut == StatutTrajet.publie ||
                  t.statut == StatutTrajet.complet,
              onTap: () {
                Navigator.pop(sheetCtx);
                _ouvrir(context, PublierTrajetPage(trajetAModifier: t));
              },
            ),
            _TuileAction(
              icone: Icons.forum_outlined,
              couleur: cs.primary,
              titre: 'Discussion du trajet',
              sousTitre: resumeDiscussion(t),
              onTap: () {
                Navigator.pop(sheetCtx);
                ouvrirDiscussion(context, t);
              },
            ),
            _TuileAction(
              icone: Icons.copy_all_outlined,
              couleur: cs.primary,
              titre: 'Dupliquer la semaine suivante',
              sousTitre: 'Republie le même trajet 7 jours plus tard',
              onTap: () async {
                Navigator.pop(sheetCtx);
                final erreur = await service.dupliquer(t);
                messenger.showSnackBar(SnackBar(
                    content: Text(erreur ?? 'Trajet dupliqué et publié')));
              },
            ),
            _TuileAction(
              icone: Icons.cancel_outlined,
              couleur: _rouge,
              titre: 'Annuler le trajet',
              sousTitre: 'Les passagers seront prévenus',
              actif: t.statut.estActif && t.statut != StatutTrajet.enCours,
              onTap: () {
                Navigator.pop(sheetCtx);
                _annulerAvecConfirmation(context, t);
              },
            ),
            if (suiteSerie.length > 1)
              _TuileAction(
                icone: Icons.event_busy_outlined,
                couleur: _rouge,
                titre: 'Annuler la suite de la série',
                sousTitre: 'Ce trajet et les ${suiteSerie.length - 1} suivants',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _annulerSerieAvecConfirmation(context, t, suiteSerie);
                },
              ),
            _TuileAction(
              icone: Icons.delete_outline,
              couleur: _rouge,
              titre: 'Supprimer',
              sousTitre: 'Retire définitivement le trajet',
              onTap: () {
                Navigator.pop(sheetCtx);
                supprimerTrajetAvecConfirmation(context, t);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _annulerAvecConfirmation(BuildContext context, Trajet t) async {
  final messenger = ScaffoldMessenger.of(context);
  final n = t.placesReservees;
  final confirme = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      icon: const Icon(Icons.cancel_outlined, color: _rouge),
      title: const Text('Annuler ce trajet ?'),
      content: Text(
        '${t.villeDepart} → ${t.villeArrivee}\n'
        '${tJourRelatif(t.dateDepart)} à ${tHeure(t.dateDepart)}\n\n'
        '${n == 0 ? 'Aucun passager n’a encore réservé.' : '$n passager(s) seront prévenus de l’annulation.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: const Text('Retour'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _rouge),
          onPressed: () => Navigator.pop(dctx, true),
          child: const Text('Annuler le trajet'),
        ),
      ],
    ),
  );
  if (confirme != true) return;
  await TrajetService.instance.annuler(t.id);
  messenger.showSnackBar(const SnackBar(
      content: Text('Trajet annulé, les passagers seront prévenus')));
}

Future<void> _annulerSerieAvecConfirmation(
    BuildContext context, Trajet t, List<Trajet> suite) async {
  final messenger = ScaffoldMessenger.of(context);
  final passagers = suite.fold<int>(0, (s, x) => s + x.placesReservees);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      icon: const Icon(Icons.event_busy_outlined, color: _rouge),
      title: Text('Annuler ${suite.length} trajets ?'),
      content: Text(
        '${t.villeDepart} → ${t.villeArrivee}, à ${tHeure(t.dateDepart)}\n'
        'Du ${tJourSemaine(suite.first.dateDepart)} ${tDateCourte(suite.first.dateDepart)} '
        'au ${tJourSemaine(suite.last.dateDepart)} ${tDateCourte(suite.last.dateDepart)}.\n\n'
        '${passagers == 0 ? 'Aucun passager n’a encore réservé.' : '$passagers place(s) réservée(s) : les passagers seront prévenus.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: const Text('Retour'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _rouge),
          onPressed: () => Navigator.pop(dctx, true),
          child: const Text('Tout annuler'),
        ),
      ],
    ),
  );
  if (confirme != true) return;
  final n = await TrajetService.instance.annulerSerie(t);
  messenger.showSnackBar(
      SnackBar(content: Text('$n trajet(s) de la série annulé(s)')));
}

class _TuileAction extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String sousTitre;
  final bool actif;
  final VoidCallback onTap;
  const _TuileAction({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
    this.actif = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: actif,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: couleur.withValues(alpha: actif ? 0.1 : 0.04),
        child: Icon(icone,
            size: 20, color: actif ? couleur : couleur.withValues(alpha: 0.4)),
      ),
      title: Text(titre,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: couleur == _rouge && actif ? _rouge : null)),
      subtitle: Text(sousTitre, style: const TextStyle(fontSize: 12)),
    );
  }
}
