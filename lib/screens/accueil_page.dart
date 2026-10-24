import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/helpers.dart';
import '../models/trajet.dart';

import '../features/trajet/services/trajet_service.dart';
import '../features/trajet/screens/recherche_trajet_page.dart';
import '../features/trajet/screens/publier_trajet_page.dart';
import '../features/trajet/screens/mes_trajets_page.dart';
import '../features/planning/screens/planning_home.dart';
import '../features/messagerie/screens/messagerie_page.dart';
import '../features/reclamation/screens/reclamation_page.dart';
import '../features/recommendation/screens/recommendation_page.dart';
import '../features/user/screens/profile_page.dart';
import '../features/user/services/user_service.dart';
import '../features/user/screens/widgets/user_avatar_view.dart';
import '../widgets/curved_nav_bar.dart';

class AccueilPage extends StatefulWidget {
  final int initialIndex;
  const AccueilPage({super.key, this.initialIndex = 0});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.fond,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeDashboardTab(
            onNavigateToTab: _onTabSelected,
          ),
          const MesTrajetsPage(isStandalone: false),
          const MessageriePage(isStandalone: false),
          const ReclamationPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: CurvedFloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        items: const [
          CurvedNavBarItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          CurvedNavBarItem(
            icon: Icons.directions_car_outlined,
            activeIcon: Icons.directions_car_rounded,
            label: 'Trajet',
          ),
          CurvedNavBarItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messagerie',
            badge: 2,
          ),
          CurvedNavBarItem(
            icon: Icons.report_problem_outlined,
            activeIcon: Icons.report_problem_rounded,
            label: 'Réclamation',
          ),
          CurvedNavBarItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 0 : DASHBOARD PRINCIPAL (HOME)
// ============================================================================

class _HomeDashboardTab extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const _HomeDashboardTab({required this.onNavigateToTab});

  void _ouvrir(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([TrajetService.instance, UserService.instance]),
        builder: (context, _) {
          final currentUser = UserService.instance.currentUser;
          final prochains = TrajetService.instance.mesTrajets(
            monId,
            aVenir: true,
          );

          final prochain = prochains.isEmpty ? null : prochains.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              // =====================================================
              // HEADER : SALUTATION & AVATAR
              // =====================================================
              Row(
                children: [
                  UserAvatarView(
                    user: currentUser,
                    radius: 24,
                    onTap: () => onNavigateToTab(4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bonjour,',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.texte2,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                currentUser != null
                                    ? '${currentUser.prenom} ${currentUser.nom}'
                                    : monNom,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.texte,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (currentUser != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: currentUser.isConducteur
                                      ? AppColors.champFond
                                      : AppColors.primaireDoux,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentUser.role.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: currentUser.isConducteur
                                        ? AppColors.accent
                                        : AppColors.primaire,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => onNavigateToTab(2),
                    icon: const Badge(
                      smallSize: 9,
                      backgroundColor: AppColors.accent,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.texte,
                      ),
                    ),
                    tooltip: 'Notifications',
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // =====================================================
              // BARRE DE RECHERCHE RAPIDE
              // =====================================================
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _ouvrir(context, const RechercheTrajetPage());
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.bordure),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.primaire,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Où allez-vous ? (ESPRIT, Ariana...)',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.texte2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =====================================================
              // PROCHAIN TRAJET
              // =====================================================
              if (prochain != null)
                _CarteProchainTrajet(
                  trajet: prochain,
                  onVoir: () => onNavigateToTab(1),
                ),

              const SizedBox(height: 22),

              // =====================================================
              // TITRE DES RACCOURCIS
              // =====================================================
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Que voulez-vous faire ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
              ),

              // =====================================================
              // GRILLE DES RACCOURCIS
              // =====================================================
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _Raccourci(
                    'Rechercher',
                    Icons.search_rounded,
                    AppColors.champFond,
                    AppColors.primaire,
                    () => _ouvrir(context, const RechercheTrajetPage()),
                  ),
                  _Raccourci(
                    'Publier',
                    Icons.add_circle_outline_rounded,
                    AppColors.primaireDoux,
                    AppColors.primaire,
                    () => _ouvrir(context, const PublierTrajetPage()),
                  ),
                  _Raccourci(
                    'Mes trajets',
                    Icons.directions_car_rounded,
                    AppColors.creme,
                    AppColors.primaire,
                    () => onNavigateToTab(1),
                  ),
                  _Raccourci(
                    'Agenda',
                    Icons.calendar_month_outlined,
                    AppColors.sable,
                    AppColors.primaire,
                    () => _ouvrir(context, const PlanningHome()),
                  ),
                  _Raccourci(
                    'Messages',
                    Icons.chat_bubble_outline_rounded,
                    AppColors.champFond,
                    AppColors.primaire,
                    () => onNavigateToTab(2),
                    badge: 2,
                  ),
                  _Raccourci(
                    'Réclamations',
                    Icons.report_problem_outlined,
                    const Color(0xFFFDE8E8),
                    const Color(0xFFC81E1E),
                    () => onNavigateToTab(3),
                  ),
                  _Raccourci(
                    'Recommandations',
                    Icons.auto_awesome_rounded,
                    AppColors.creme,
                    AppColors.primaire,
                    () => _ouvrir(context, const RecommendationPage()),
                  ),
                  _Raccourci(
                    'Profil',
                    Icons.person_outline_rounded,
                    AppColors.accentDoux,
                    AppColors.primaire,
                    () => onNavigateToTab(4),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // =====================================================
              // BANNIÈRE ÉCO-RESPONSABLE / NOTATION
              // =====================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.champFond,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.champBordure),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.eco_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mobilité Étudiante Responsable',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaire,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Économisez du carburant et voyagez en toute confiance.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.texte2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaire,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => onNavigateToTab(1),
                      child: const Text('Voir trajets'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CARTE DU PROCHAIN TRAJET
// ============================================================

class _CarteProchainTrajet extends StatelessWidget {
  final Trajet trajet;
  final VoidCallback onVoir;

  const _CarteProchainTrajet({
    required this.trajet,
    required this.onVoir,
  });

  @override
  Widget build(BuildContext context) {
    final reserves = trajet.placesTotales - trajet.placesDispo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaire, AppColors.primaireFonce],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaire.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROCHAIN TRAJET',
                style: TextStyle(
                  color: AppColors.creme,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'En cours',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            '${trajet.villeDepart} → ${trajet.villeArrivee}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            '${fDateCourte(trajet.dateDepart)} · ${fHeure(trajet.dateDepart)} · ${trajet.vehicule}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Text(
                  '$reserves passager(s) · ${trajet.placesDispo} place(s) libre(s)',
                  style: const TextStyle(
                    color: AppColors.creme,
                    fontSize: 12.5,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaire,
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onVoir,
                child: const Text('Voir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOUTON RACCOURCI
// ============================================================

class _Raccourci extends StatelessWidget {
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bordure),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                backgroundColor: AppColors.accent,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fond,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icone,
                    color: couleur,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.texte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
