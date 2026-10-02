import 'package:flutter/material.dart';
import '../../../models/planning.dart';
import '../../../core/services/planning_database.dart';
import 'edit_planning_page.dart'; // À créer après

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  List<Planning> _plannings = [];
  String _filter = 'Toutes';

  @override
  void initState() {
    super.initState();
    _loadPlannings();
  }

  _loadPlannings() async {
    final data = await PlanningDatabase.instance.readAllPlannings();
    setState(() {
      _plannings = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtrer la liste selon le bouton sélectionné
    List<Planning> filteredList = _plannings.where((p) {
      if (_filter == 'Toutes') return true;
      return p.statut == _filter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Mon planning", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.blue),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Rechercher un lieu...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Filtres (Toutes, À venir, etc.)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip("6\nToutes", "Toutes"),
                _buildFilterChip("3\nÀ venir", "À venir"),
                _buildFilterChip("2\nTerminées", "Terminé"),
                _buildFilterChip("1\nAnnulées", "Annulé"),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Liste des trajets
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final planning = filteredList[index];
                return _buildPlanningCard(planning);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Naviguer vers l'écran d'ajout
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditPlanningPage()));
          _loadPlannings(); // Rafraîchir au retour
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanningCard(Planning planning) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(planning.heure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(planning.statut, style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("${planning.lieuDepart} → ${planning.destination}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text("${planning.role} • ${planning.placesDisponibles} places réservées", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Naviguer vers Edit avec les données
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditPlanningPage(planning: planning)));
                    _loadPlannings();
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Modifier"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await PlanningDatabase.instance.delete(planning.id!);
                    _loadPlannings();
                  },
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}