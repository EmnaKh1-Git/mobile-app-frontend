import 'package:flutter/material.dart';
import 'dart:async';

import '../../../models/planning.dart';
import '../../../core/services/planning_database.dart';

class RappelsPage extends StatefulWidget {
  const RappelsPage({super.key});

  @override
  State<RappelsPage> createState() => _RappelsPageState();
}

class _RappelsPageState extends State<RappelsPage> {
  List<Planning> _plannings = [];
  Timer? _timer;
  Duration _tempsRestant = const Duration(hours: 3, minutes: 12, seconds: 45);
  int _rappelDelai = 30;

  @override
  void initState() {
    super.initState();
    _loadPlannings();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _loadPlannings() async {
    final data = await PlanningDatabase.instance.readAllPlannings();
    setState(() {
      _plannings = data.where((p) => p.statut == 'À venir').toList();
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _tempsRestant = _tempsRestant - const Duration(seconds: 1);
          if (_tempsRestant.isNegative) {
            _tempsRestant = Duration.zero;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prochain = _plannings.isNotEmpty ? _plannings.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prochain != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PROCHAIN DÉPART',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Aujourd'hui",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${prochain.lieuDepart} → ${prochain.destination}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${prochain.date} à ${prochain.heure} · ${prochain.role}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildTimeBox(
                          _tempsRestant.inHours.toString().padLeft(2, '0'),
                          'heures',
                        ),
                        const SizedBox(width: 10),
                        _buildTimeBox(
                          (_tempsRestant.inMinutes % 60)
                              .toString()
                              .padLeft(2, '0'),
                          'minutes',
                        ),
                        const SizedBox(width: 10),
                        _buildTimeBox(
                          prochain.heure,
                          'rappel',
                          isBlue: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Aperçu de la notification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('UniRide',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(
                              prochain?.heure ?? '17:00',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Départ dans 30 min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prochain != null
                              ? "${prochain.lieuDepart} → ${prochain.destination} à ${prochain.heure}.\nRendez-vous devant l'entrée principale."
                              : "Aucun trajet à venir.",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rappels programmés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._plannings.map((p) => _buildRappelItem(p)).toList(),
            const SizedBox(height: 24),
            const Text(
              'Délai par défaut',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDelaiChip(15, '15 min'),
                const SizedBox(width: 8),
                _buildDelaiChip(30, '30 min'),
                const SizedBox(width: 8),
                _buildDelaiChip(60, '1 h'),
                const SizedBox(width: 8),
                _buildDelaiChip(1440, '1 jour'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String value, String label, {bool isBlue = true}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isBlue ? Colors.white24 : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: isBlue ? Colors.white : Colors.blue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isBlue ? Colors.white70 : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRappelItem(Planning p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Auj.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${p.lieuDepart} → ${p.destination}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Départ ${p.heure} · rappel 30 min avant",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: p.rappelActif,
            activeColor: Colors.blue,
            onChanged: (val) async {
              final updated = Planning(
                id: p.id,
                lieuDepart: p.lieuDepart,
                destination: p.destination,
                date: p.date,
                heure: p.heure,
                statut: p.statut,
                rappelActif: val,
                rappelDelai: p.rappelDelai,
                role: p.role,
                placesDisponibles: p.placesDisponibles,
              );
              await PlanningDatabase.instance.update(updated);
              _loadPlannings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDelaiChip(int minutes, String label) {
    final isSelected = _rappelDelai == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rappelDelai = minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}