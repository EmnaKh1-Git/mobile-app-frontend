import 'package:flutter/material.dart';

import '../app/theme.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/helpers.dart';

import '../models/trajet.dart';

import '../features/trajet/services/trajet_service.dart';

import '../features/trajet/screens/recherche_trajet_page.dart';
import '../features/trajet/screens/publier_trajet_page.dart';
import '../features/trajet/screens/mes_trajets_page.dart';
import '../features/trajet/screens/detail_trajet_page.dart';
import '../features/trajet/widgets/trajet_card.dart';
import '../features/planning/screens/planning_home.dart';


import '../features/messagerie/screens/messagerie_page.dart';
import '../features/recommendation/screens/recommendation_page.dart';
import '../features/user/screens/profile_page.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  void _ouvrir(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TrajetService.instance,
          builder: (context, _) {
            final prochains = TrajetService.instance.mesTrajets(
              monId,
              aVenir: true,
            );

            final prochain =
            prochains.isEmpty ? null : prochains.first;

            // Module Trajets : 3 prochains départs réservables
            final departs = TrajetService.instance
                .rechercher()
                .take(3)
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24,
              ),
              children: [
                // =====================================================
                // HEADER
                // =====================================================

                Row(
                  children: [
                    const CircleAvatar(
                      radius: 23,
                      backgroundColor: AppColors.primaire,
                      child: Text(
                        'Y',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour,',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.texte2,
                            ),
                          ),
                          Text(
                            monNom,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton.outlined(
                      onPressed: () {},
                      icon: const Badge(
                        smallSize: 9,
                        backgroundColor:
                        AppColors.accent,
                        child: Icon(
                          Icons.notifications_none,
                        ),
                      ),
                      tooltip: 'Notifications',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // =====================================================
                // BARRE DE RECHERCHE
                // =====================================================

                InkWell(
                  borderRadius:
                  BorderRadius.circular(18),
                  onTap: () {
                    _ouvrir(
                      context,
                      const RechercheTrajetPage(),
                    );
                  },
                  child: Container(
                    height: 56,
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.bordure,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search,
                          color:
                          AppColors.primaire,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Où allez-vous ?',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                            AppColors.texte2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // =====================================================
                // PROCHAIN TRAJET
                // =====================================================

                if (!TrajetService.instance.estCharge)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (prochain != null) ...[
                  _CarteProchainTrajet(
                    trajet: prochain,
                    onVoir: () {
                      _ouvrir(
                        context,
                        DetailTrajetPage(trajet: prochain),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _ouvrir(
                          context,
                          const MesTrajetsPage(),
                        );
                      },
                      icon: const Icon(
                        Icons.directions_car_outlined,
                        size: 18,
                      ),
                      label: Text(
                        'Gérer mes trajets (${prochains.length})',
                      ),
                    ),
                  ),
                ] else
                  _CartePublier(
                    onPublier: () {
                      _ouvrir(
                        context,
                        const PublierTrajetPage(),
                      );
                    },
                  ),

                const SizedBox(height: 20),

                // =====================================================
                // TITRE DES RACCOURCIS
                // =====================================================

                const Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    bottom: 10,
                  ),
                  child: Text(
                    'Que voulez-vous faire ?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                // =====================================================
                // RACCOURCIS
                // =====================================================

                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    _Raccourci(
                      'Rechercher',
                      Icons.search,
                      AppColors.primaireDoux,
                      AppColors.primaire,
                          () {
                        _ouvrir(
                          context,
                          const RechercheTrajetPage(),
                        );
                      },
                    ),

                    _Raccourci(
                      'Publier',
                      Icons.add_circle_outline,
                      AppColors.primaireDoux,
                      AppColors.primaire,
                          () {
                        _ouvrir(
                          context,
                          const PublierTrajetPage(),
                        );
                      },
                    ),

                    _Raccourci(
                      'Agenda',
                      Icons.calendar_month_outlined,
                      AppColors.accentDoux,
                      AppColors.accent,
                          () {
                        _ouvrir(
                          context,
                          const PlanningHome(),
                        );
                      },
                    ),

                    _Raccourci(
                      'Messages',
                      Icons.chat_bubble_outline,
                      AppColors.infoFond,
                      AppColors.infoTexte,
                          () {
                        _ouvrir(
                          context,
                          const MessageriePage(),
                        );
                      },
                      badge: 2,
                    ),

                    _Raccourci(
                      'Recommandations',
                      Icons.auto_awesome_outlined,
                      AppColors.infoFond,
                      AppColors.infoTexte,
                          () {
                        _ouvrir(
                          context,
                          const RecommendationPage(),
                        );
                      },
                    ),

                    _Raccourci(
                      'Profil',
                      Icons.person_outline,
                      AppColors.accentDoux,
                      AppColors.accent,
                          () {
                        _ouvrir(
                          context,
                          const ProfilePage(),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // =====================================================
                // DÉPARTS DISPONIBLES (module Trajets)
                // =====================================================

                if (departs.isNotEmpty) ...[
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'Départs disponibles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _ouvrir(
                            context,
                            const RechercheTrajetPage(),
                          );
                        },
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                  for (final t in departs)
                    TrajetCard(
                      trajet: t,
                      onTap: () {
                        _ouvrir(
                          context,
                          DetailTrajetPage(trajet: t),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],

                // =====================================================
                // RAPPEL NOTATION
                // =====================================================

                Container(
                  padding:
                  const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFFFF1EC),
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor:
                        AppColors.accentDoux,
                        child: Icon(
                          Icons.star_outline,
                          color:
                          AppColors.accent,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Text(
                          'Notez votre trajet Tunis → Hammamet du 27 sept.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),

                      FilledButton(
                        style:
                        FilledButton.styleFrom(
                          backgroundColor:
                          AppColors.accent,
                          minimumSize:
                          const Size(0, 40),
                        ),
                        onPressed: () {
                          // La fonctionnalité de notation
                          // sera ajoutée plus tard.
                        },
                        child: const Text(
                          'Noter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// CARTE DU PROCHAIN TRAJET
// ============================================================

class _CarteProchainTrajet
    extends StatelessWidget {
  final Trajet trajet;
  final VoidCallback onVoir;

  const _CarteProchainTrajet({
    required this.trajet,
    required this.onVoir,
  });

  @override
  Widget build(BuildContext context) {
    final reserves =
        trajet.placesTotales -
            trajet.placesDispo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaire,
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'PROCHAIN TRAJET',
            style: TextStyle(
              color: Color(0xFFC9D6FF),
              fontSize: 13,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            '${trajet.villeDepart} → '
                '${trajet.villeArrivee}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          Text(
            '${fDateCourte(trajet.dateDepart)} · '
                '${fHeure(trajet.dateDepart)} · '
                '${trajet.vehicule}',
            style: const TextStyle(
              color: Color(0xFFDDE5FF),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Text(
                  '$reserves passager(s) · '
                      '${trajet.placesDispo} '
                      'place(s) libre(s)',
                  style: const TextStyle(
                    color: Color(0xFFDDE5FF),
                    fontSize: 13,
                  ),
                ),
              ),

              FilledButton(
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  Colors.white,
                  foregroundColor:
                  AppColors.primaire,
                  minimumSize:
                  const Size(0, 40),
                ),
                onPressed: onVoir,
                child: const Text(
                  'Voir',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE « PUBLIER » (aucun trajet à venir) — module Trajets
// ============================================================

class _CartePublier extends StatelessWidget {
  final VoidCallback onPublier;

  const _CartePublier({required this.onPublier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaireDoux,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaire,
            child: Icon(
              Icons.directions_car,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun trajet prévu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Publiez un trajet et partagez vos frais.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.texte2,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaire,
              minimumSize: const Size(0, 40),
            ),
            onPressed: onPublier,
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RACCOURCI
// ============================================================

class _Raccourci
    extends StatelessWidget {
  final String label;
  final IconData icone;
  final Color fond;
  final Color couleur;
  final VoidCallback onTap;
  final int badge;

  const _Raccourci(
      this.label,
      this.icone,
      this.fond,
      this.couleur,
      this.onTap, {
        this.badge = 0,
      });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(18),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color:
              const Color(0xFFE9ECF5),
            ),
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible:
                badge > 0,
                label: Text('$badge'),
                backgroundColor:
                AppColors.accent,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration:
                  BoxDecoration(
                    color: fond,
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    icone,
                    color: couleur,
                    size: 21,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                label,
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}