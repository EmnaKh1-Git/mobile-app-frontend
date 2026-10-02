import 'package:flutter/material.dart';
import '../../../models/planning.dart';
import '../../../core/services/planning_database.dart';

class EditPlanningPage extends StatefulWidget {
  final Planning? planning;

  const EditPlanningPage({super.key, this.planning});

  @override
  State<EditPlanningPage> createState() => _EditPlanningPageState();
}

class _EditPlanningPageState extends State<EditPlanningPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _departController;
  late TextEditingController _destController;
  String _selectedDate = "Lun. 5 oct.";
  String _selectedTime = "07:30";
  String _status = "À venir";
  bool _rappelActif = true;

  @override
  void initState() {
    super.initState();
    _departController =
        TextEditingController(text: widget.planning?.lieuDepart ?? "");
    _destController =
        TextEditingController(text: widget.planning?.destination ?? "");
    if (widget.planning != null) {
      _selectedDate = widget.planning!.date;
      _selectedTime = widget.planning!.heure;
      _status = widget.planning!.statut;
      _rappelActif = widget.planning!.rappelActif;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.planning == null
            ? "Nouvelle planification"
            : "Modifier la planification"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("APERÇU",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      "${_departController.text} → ${_destController.text}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text("$_selectedDate à $_selectedTime • $_status",
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildTextField("Lieu de départ", _departController),
                    const SizedBox(height: 16),
                    _buildTextField("Destination", _destController),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker("Date", _selectedDate,
                                  (val) => setState(() => _selectedDate = val)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDatePicker("Heure", _selectedTime,
                                  (val) => setState(() => _selectedTime = val)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("Statut",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip("À venir"),
                  const SizedBox(width: 8),
                  _buildStatusChip("Terminé"),
                  const SizedBox(width: 8),
                  _buildStatusChip("Annulé"),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Colors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Rappel 30 min avant",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Activé - notification à 07:00",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _rappelActif,
                      onChanged: (val) => setState(() => _rappelActif = val),
                      activeColor: Colors.blue,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        if (widget.planning != null) {
                          await PlanningDatabase.instance
                              .delete(widget.planning!.id!);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePlanning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Enregistrer les modifications",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
      String label, String value, Function(String) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            if (label == "Date") {
              onUpdate("Mar. 6 oct.");
            } else {
              onUpdate("08:00");
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Widget _buildStatusChip(String label) {
    bool isSelected = _status == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black)),
          ),
        ),
      ),
    );
  }

  void _savePlanning() async {
    final newPlanning = Planning(
      id: widget.planning?.id,
      lieuDepart: _departController.text,
      destination: _destController.text,
      date: _selectedDate,
      heure: _selectedTime,
      statut: _status,
      rappelActif: _rappelActif,
      rappelDelai: 30,
      role: widget.planning?.role ?? 'Conducteur',
      placesDisponibles: widget.planning?.placesDisponibles ?? 0,
    );

    if (widget.planning == null) {
      await PlanningDatabase.instance.create(newPlanning);
    } else {
      await PlanningDatabase.instance.update(newPlanning);
    }

    if (mounted) Navigator.pop(context);
  }
}