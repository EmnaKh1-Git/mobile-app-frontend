// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/prix_propose.dart
//  Choix du prix par place, comme sur inDrive :
//      [ − ]   8,50 DT   [ + ]
//           Prix recommandé : 8 DT
//  + bandeau de majoration (heure de pointe / nuit)
//  + avis sur le prix choisi (bas, idéal, élevé…)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/tarif_service.dart';
import '../utils/trajet_format.dart';

class PrixPropose extends StatelessWidget {
  final double prix;
  final EstimationPrix estimation;
  final ValueChanged<double> onChanged;

  const PrixPropose({
    super.key,
    required this.prix,
    required this.estimation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = estimation;
    const pas = TarifService.pas;
    final peutBaisser = prix > 0;
    final peutMonter = prix + pas <= e.prixMax + 0.001;
    final avis = _avis(e.niveau(prix));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Bandeau « Forte demande » ----
        if (e.motifMajoration != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFFB43BD9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${e.motifMajoration} : prix recommandé '
                    '+${(e.majoration * 100).round()} %',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        // ---- − prix + ----
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _BoutonPrix(
                icone: Icons.remove,
                tooltip: 'Baisser de ${tPrix(pas)}',
                onPressed: peutBaisser
                    ? () => onChanged(
                        TarifService.arrondir(math.max(0.0, prix - pas)))
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      child: Text(
                        prix <= 0 ? 'Gratuit' : tPrix(prix),
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prix recommandé : ${tPrix(e.prixIdeal)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _BoutonPrix(
                icone: Icons.add,
                tooltip: 'Augmenter de ${tPrix(pas)}',
                onPressed: peutMonter
                    ? () => onChanged(
                        TarifService.arrondir(math.min(e.prixMax, prix + pas)))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ---- Avis sur le prix ----
        Row(
          children: [
            Icon(avis.icone, size: 18, color: avis.couleur),
            const SizedBox(width: 6),
            Expanded(
              child: Text(avis.message,
                  style: TextStyle(fontSize: 13, color: avis.couleur)),
            ),
            if ((prix - e.prixIdeal).abs() > 0.001)
              TextButton(
                onPressed: () => onChanged(e.prixIdeal),
                child: const Text('Prix recommandé'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Frais du trajet (carburant + usure) : ${tPrix(_deuxDecimales(e.coutTrajet))}'
          ' pour ${e.distanceKm.toStringAsFixed(1)} km, partagés entre vous et '
          '${e.places} passager${e.places > 1 ? 's' : ''}. '
          'Plafond : ${tPrix(e.prixMax)} par place.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  static double _deuxDecimales(double v) => (v * 100).round() / 100;

  _Avis _avis(NiveauPrix n) {
    switch (n) {
      case NiveauPrix.gratuit:
        return const _Avis(Icons.volunteer_activism, Color(0xFF2E7D32),
            'Trajet gratuit : merci pour les étudiants !');
      case NiveauPrix.bas:
        return const _Avis(Icons.south, Color(0xFFE67E22),
            'Prix bas : vos frais ne seront pas couverts.');
      case NiveauPrix.ideal:
        return const _Avis(Icons.check_circle, Color(0xFF2E7D32),
            'Prix idéal : partage équitable des frais.');
      case NiveauPrix.eleve:
        return const _Avis(Icons.north, Color(0xFFE67E22),
            'Prix élevé : les passagers réserveront moins vite.');
      case NiveauPrix.tropCher:
        return const _Avis(Icons.error_outline, Color(0xFFC62828),
            'Trop cher pour du covoiturage étudiant.');
    }
  }
}

class _Avis {
  final IconData icone;
  final Color couleur;
  final String message;
  const _Avis(this.icone, this.couleur, this.message);
}

class _BoutonPrix extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback? onPressed;
  const _BoutonPrix(
      {required this.icone, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        disabledBackgroundColor: cs.surface.withValues(alpha: 0.5),
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(icone),
    );
  }
}
