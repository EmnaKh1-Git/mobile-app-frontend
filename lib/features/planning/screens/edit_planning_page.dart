import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/planning.dart';
import '../../../core/services/planning_database.dart';
import '../widgets/maplibre_location_picker.dart'; // <-- Import de votre nouveau widget

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

  double? _destLat;
  double? _destLng;

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String _status = "À venir";
  bool _rappelActif = true;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _departController =
        TextEditingController(text: widget.planning?.lieuDepart ?? "");
    _destController =
        TextEditingController(text: widget.planning?.destination ?? "");

    if (widget.planning != null) {
      _status = widget.planning!.statut;
      _rappelActif = widget.planning!.rappelActif;
      _destLat = widget.planning!.destinationLat;
      _destLng = widget.planning!.destinationLng;

      final parsed = _tryParseDate(
        widget.planning!.date,
        widget.planning!.heure,
      );
      if (parsed != null) {
        _selectedDateTime = parsed;
      }
    }
  }

  DateTime? _tryParseDate(String dateStr, String heureStr) {
    try {
      final dayMatch = RegExp(r'(\d{1,2})').firstMatch(dateStr);
      if (dayMatch == null) return null;
      final day = int.parse(dayMatch.group(1)!);
      final timeParts = heureStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String get _dateFormatee {
    final formatted = DateFormat('EEE d MMM', 'fr_FR').format(_selectedDateTime);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String get _heureFormatee => DateFormat('HH:mm').format(_selectedDateTime);

  // ============================================================
  // SÉLECTION DE LA DESTINATION AVEC MAPLIBRE
  // ============================================================
  Future<void> _pickDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapLibreLocationPicker()),
    );

    if (result != null) {
      setState(() {
        _destController.text = result['address'];
        _destLat = result['lat'];
        _destLng = result['lng'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.planning == null
              ? "Nouvelle planification"
              : "Modifier la planification",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
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
                      "${_departController.text.isEmpty ? '...' : _departController.text} → ${_destController.text.isEmpty ? '...' : _destController.text}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text("$_dateFormatee à $_heureFormatee • $_status",
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
                    _buildTextField(
                      "Lieu de départ",
                      _departController,
                      hint: "Ex: Mnihla",
                      obligatoire: true,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickDestination,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          "Destination",
                          _destController,
                          hint: "Cliquez ici pour choisir sur la carte",
                          obligatoire: true,
                          suffixIcon: const Icon(Icons.map, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimeField(
                            label: "Date",
                            value: _dateFormatee,
                            icon: Icons.calendar_today,
                            onTap: _pickDate,
                            obligatoire: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateTimeField(
                            label: "Heure",
                            value: _heureFormatee,
                            icon: Icons.access_time,
                            onTap: _pickTime,
                            obligatoire: true,
                          ),
                        ),
                      ],
                    ),
                    if (_dateError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _dateError!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    const Icon(Icons.notifications_active, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Rappel 30 min avant",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _rappelActif
                                ? "Activé - notification à ${_rappelHeure()}"
                                : "Désactivé",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _rappelActif,
                      onChanged: (val) => setState(() => _rappelActif = val),
                      activeThumbColor: Colors.blue,
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
                      onPressed: _onDeletePressed,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obligatoire = false,
    int minLength = 3,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
            children: [
              TextSpan(text: label),
              if (obligatoire)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Ce champ est obligatoire";
            }
            if (value.trim().length < minLength) {
              return "Minimum $minLength caractères";
            }
            return null;
          },
          onChanged: (val) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool obligatoire = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            children: [
              TextSpan(text: label),
              if (obligatoire)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(value,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isBefore(now) ? now : _selectedDateTime,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      locale: const Locale('fr', 'FR'),
      helpText: "Sélectionner la date",
      cancelText: "Annuler",
      confirmText: "Valider",
    );

    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
            picked.year, picked.month, picked.day, _selectedDateTime.hour, _selectedDateTime.minute);
        _dateError = _validateDateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      helpText: "Sélectionner l'heure",
      cancelText: "Annuler",
      confirmText: "Valider",
    );

    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(_selectedDateTime.year,
            _selectedDateTime.month, _selectedDateTime.day, picked.hour, picked.minute);
        _dateError = _validateDateTime();
      });
    }
  }

  String? _validateDateTime() {
    final now = DateTime.now();
    if (_selectedDateTime.isBefore(now)) {
      return "La date et l'heure doivent être dans le futur.";
    }
    if (_selectedDateTime.difference(now).inMinutes < 15) {
      return "Le trajet doit être planifié au moins 15 minutes à l'avance.";
    }
    return null;
  }

  String _rappelHeure() {
    final rappel = _selectedDateTime.subtract(const Duration(minutes: 30));
    return DateFormat('HH:mm').format(rappel);
  }

  void _onDeletePressed() async {
    if (widget.planning == null) {
      Navigator.pop(context);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Voulez-vous vraiment supprimer ce trajet planifié ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await PlanningDatabase.instance.delete(widget.planning!.id!);
      if (mounted) Navigator.pop(context);
    }
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
            border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  void _savePlanning() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez corriger les erreurs du formulaire"), backgroundColor: Colors.red),
      );
      return;
    }

    final dateError = _validateDateTime();
    if (dateError != null) {
      setState(() => _dateError = dateError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateError), backgroundColor: Colors.red),
      );
      return;
    }

    final newPlanning = Planning(
      id: widget.planning?.id,
      lieuDepart: _departController.text.trim(),
      destination: _destController.text.trim(),
      destinationLat: _destLat,
      destinationLng: _destLng,
      date: _dateFormatee,
      heure: _heureFormatee,
      statut: _status,
      rappelActif: _rappelActif,
      rappelDelai: 30,
      role: widget.planning?.role ?? 'Conducteur',
      placesDisponibles: widget.planning?.placesDisponibles ?? 0,
    );

    try {
      if (widget.planning == null) {
        await PlanningDatabase.instance.create(newPlanning);
      } else {
        await PlanningDatabase.instance.update(newPlanning);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.planning == null ? "Trajet créé avec succès" : "Trajet modifié avec succès"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}