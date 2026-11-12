import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/reclamation.dart';
import '../services/reclamation_ai_service.dart';
import '../services/reclamation_service.dart';
import '../widgets/reclamation_widgets.dart';
import 'reclamation_details_page.dart';

/// Tableau de bord administrateur : KPI, SLA, répartition, synthèse IA.
class ReclamationStatsPage extends StatefulWidget {
  const ReclamationStatsPage({super.key});

  @override
  State<ReclamationStatsPage> createState() => _ReclamationStatsPageState();
}

class _ReclamationStatsPageState extends State<ReclamationStatsPage> {
  final ReclamationAiService _ai = ReclamationAiService();
  String? _synthese;
  bool _syntheseEnCours = false;

  Future<void> _genererSynthese(List<Reclamation> liste) async {
    setState(() => _syntheseEnCours = true);
    try {
      final texte = await _ai.syntheseAdmin(liste);
      if (mounted) setState(() => _synthese = texte);
    } on ReclamationAiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _syntheseEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord réclamations')),
      body: ListenableBuilder(
        listenable: ReclamationService.instance,
        builder: (context, _) {
          final service = ReclamationService.instance;
          final liste = service.reclamations;
          final s = service.statistiques();
          final enRetard = liste.where((r) => r.estEnRetard).toList()
            ..sort((a, b) => a.echeance.compareTo(b.echeance));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  _Kpi('Total', '${s.total}', Icons.all_inbox_rounded,
                      AppColors.primaire),
                  _Kpi('Ouvertes', '${s.ouvertes}', Icons.inbox_rounded,
                      const Color(0xFF0057B8)),
                  _Kpi('Hors délai', '${s.enRetard}', Icons.timer_off_outlined,
                      const Color(0xFFC62828)),
                  _Kpi('Urgentes ouvertes', '${s.urgentesOuvertes}',
                      Icons.priority_high_rounded, const Color(0xFFC62828)),
                  _Kpi(
                    'Respect SLA',
                    '${(s.tauxRespectSla * 100).round()} %',
                    Icons.speed_rounded,
                    s.tauxRespectSla >= 0.8
                        ? AppColors.primaire
                        : AppColors.alerte,
                  ),
                  _Kpi(
                    'Satisfaction',
                    s.satisfactionMoyenne == null
                        ? '—'
                        : '${s.satisfactionMoyenne!.toStringAsFixed(1)} / 5',
                    Icons.star_rounded,
                    const Color(0xFFE5A100),
                  ),
                  _Kpi(
                    '1re réponse (moy.)',
                    s.delaiMoyenPremiereReponse == null
                        ? '—'
                        : formatDuree(s.delaiMoyenPremiereReponse!),
                    Icons.reply_rounded,
                    AppColors.texte2,
                  ),
                  _Kpi(
                    'Résolution (moy.)',
                    s.delaiMoyenResolution == null
                        ? '—'
                        : formatDuree(s.delaiMoyenResolution!),
                    Icons.task_alt_rounded,
                    AppColors.texte2,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                titre: 'Par statut',
                child: _Barres(
                  valeurs: {
                    for (final e in s.parStatut.entries) e.key.label: e.value,
                  },
                  total: s.total,
                ),
              ),
              _Section(
                titre: 'Par catégorie',
                child: _Barres(
                  valeurs: Map.fromEntries(
                    s.parCategorie.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)),
                  ),
                  total: s.total,
                ),
              ),
              _Section(
                titre: 'Synthèse IA (DeepSeek)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_synthese != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaireDoux,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          _synthese!,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _syntheseEnCours
                          ? null
                          : () => _genererSynthese(liste),
                      icon: _syntheseEnCours
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _synthese == null
                            ? 'Analyser les problèmes récurrents'
                            : 'Régénérer la synthèse',
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                titre: 'À traiter en priorité (${enRetard.length} hors délai)',
                child: enRetard.isEmpty
                    ? const Text(
                        'Aucune réclamation hors délai 🎉',
                        style: TextStyle(color: AppColors.texte2),
                      )
                    : Column(
                        children: enRetard
                            .take(10)
                            .map(
                              (r) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: PrioriteBadge(
                                  priorite: r.priorite,
                                  compact: true,
                                ),
                                title: Text(
                                  r.sujet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: SlaIndicator(reclamation: r),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReclamationDetailsPage(reclamation: r),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String libelle;
  final String valeur;
  final IconData icone;
  final Color couleur;

  const _Kpi(this.libelle, this.valeur, this.icone, this.couleur);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icone, color: couleur, size: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
          ),
          Text(
            libelle,
            style: const TextStyle(fontSize: 12, color: AppColors.texte2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final Widget child;

  const _Section({required this.titre, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Barres extends StatelessWidget {
  final Map<String, int> valeurs;
  final int total;

  const _Barres({required this.valeurs, required this.total});

  @override
  Widget build(BuildContext context) {
    if (valeurs.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.texte2));
    }
    return Column(
      children: valeurs.entries.map((e) {
        final ratio = total == 0 ? 0.0 : e.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  e.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: AppColors.champFond,
                    color: AppColors.primaire,
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${e.value}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
