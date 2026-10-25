import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../services/trajet_service.dart';
import 'publier_trajet_page.dart';
import 'recherche_trajet_page.dart';

class MesTrajetsPage extends StatefulWidget {
  final bool isStandalone;
  const MesTrajetsPage({super.key, this.isStandalone = false});

  @override
  State<MesTrajetsPage> createState() => _MesTrajetsPageState();
}

class _MesTrajetsPageState extends State<MesTrajetsPage> {
  int _selectedFilter = 0; // 0 = À venir, 1 = Historique

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text(
          'Mes Trajets',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        automaticallyImplyLeading: widget.isStandalone,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.primaire),
            tooltip: 'Rechercher un trajet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RechercheTrajetPage()),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: TrajetService.instance,
        builder: (context, _) {
          final trajets = TrajetService.instance.mesTrajets(
            monId,
            aVenir: _selectedFilter == 0,
          );

          return Column(
            children: [
              // Sélecteur d'onglets À venir / Historique
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.champFond,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = 0),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _selectedFilter == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _selectedFilter == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'À venir',
                                style: TextStyle(
                                  fontWeight: _selectedFilter == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedFilter == 0 ? AppColors.primaire : AppColors.texte2,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = 1),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _selectedFilter == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _selectedFilter == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Historique',
                                style: TextStyle(
                                  fontWeight: _selectedFilter == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedFilter == 1 ? AppColors.primaire : AppColors.texte2,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bannière de publication rapide
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaire, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaire.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add_road_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vous êtes conducteur ?',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Publiez votre trajet et partagez vos frais',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PublierTrajetPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaire,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Publier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Liste des trajets
              Expanded(
                child: trajets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                color: AppColors.champFond,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_car_filled_rounded, size: 36, color: AppColors.primaire),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 0 ? 'Aucun trajet à venir' : 'Aucun trajet dans l\'historique',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.texte),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Recherchez un trajet ou publiez le vôtre.',
                              style: TextStyle(fontSize: 13, color: AppColors.texte2),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RechercheTrajetPage()),
                                );
                              },
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Rechercher un trajet'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaire,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount: trajets.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final trajet = trajets[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.bordure),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.texte2),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${fDateCourte(trajet.dateDepart)} · ${fHeure(trajet.dateDepart)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.texte2),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.champFond,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        trajet.vehicule,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primaire,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(Icons.trip_origin_rounded, size: 16, color: AppColors.primaire),
                                        Container(width: 2, height: 20, color: AppColors.bordure),
                                        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.accent),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trajet.villeDepart,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            trajet.villeArrivee,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.airline_seat_recline_normal_rounded, size: 16, color: AppColors.texte2),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${trajet.placesDispo} / ${trajet.placesTotales} places',
                                              style: const TextStyle(fontSize: 12, color: AppColors.texte2),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
