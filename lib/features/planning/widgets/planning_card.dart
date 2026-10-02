// lib/features/planning/widgets/planning_card.dart
import 'package:flutter/material.dart';
import '../../../models/planning.dart';

class PlanningCard extends StatelessWidget {
  final Planning planning;
  final VoidCallback? onTap;
  final bool showActions;

  const PlanningCard({
    super.key,
    required this.planning,
    this.onTap,
    this.showActions = false,
  });

  Color get _statutColor {
    switch (planning.statut) {
      case 'À venir':
        return Colors.blue;
      case 'Terminé':
        return Colors.green;
      case 'Annulé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heure
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planning.heure,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Barre verticale colorée
            Container(
              width: 3,
              height: 55,
              decoration: BoxDecoration(
                color: _statutColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${planning.lieuDepart} → ${planning.destination}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planning.role == 'Conducteur'
                        ? "Conducteur"
                        : "${planning.placesDisponibles} places réservées",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Badge statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statutColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                planning.role,
                style: TextStyle(
                  fontSize: 11,
                  color: _statutColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}