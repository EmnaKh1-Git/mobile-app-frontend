import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../models/reclamation.dart';
import '../services/reclamation_service.dart';

class ReclamationPage extends StatelessWidget {
  const ReclamationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réclamations'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AjouterReclamationPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nouvelle réclamation',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ReclamationService.instance,
        builder: (context, _) {
          final reclamations = ReclamationService.instance.reclamations;

          if (reclamations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune réclamation enregistrée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.texte2),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reclamations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reclamation = reclamations[index];

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReclamationDetailsPage(
                        reclamation: reclamation,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.bordure),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaireDoux,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.report_problem_outlined,
                              color: AppColors.primaire,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reclamation.sujet,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reclamation.typeLabel,
                                  style: const TextStyle(
                                    color: AppColors.texte2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: reclamation.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reclamation.trajet,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaire,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd MMM yyyy', 'fr_FR').format(reclamation.date),
                        style: const TextStyle(
                          color: AppColors.texte2,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AjouterReclamationPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
    );
  }
}

class ReclamationDetailsPage extends StatefulWidget {
  final Reclamation reclamation;

  const ReclamationDetailsPage({super.key, required this.reclamation});

  @override
  State<ReclamationDetailsPage> createState() => _ReclamationDetailsPageState();
}

class _ReclamationDetailsPageState extends State<ReclamationDetailsPage> {
  late ReclamationStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.reclamation.status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.reclamation.sujet,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Type', value: widget.reclamation.typeLabel),
                  _InfoRow(label: 'Trajet', value: widget.reclamation.trajet),
                  _InfoRow(
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy', 'fr_FR')
                        .format(widget.reclamation.date),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Statut',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ReclamationStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ReclamationStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _status = value;
                      });

                      ReclamationService.instance.mettreAJourStatut(
                        widget.reclamation.id,
                        value,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bordure),
            ),
            child: Text(
              widget.reclamation.description,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ReclamationStatus status) {
    switch (status) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
    }
  }
}

class AjouterReclamationPage extends StatefulWidget {
  const AjouterReclamationPage({super.key});

  @override
  State<AjouterReclamationPage> createState() => _AjouterReclamationPageState();
}

class _AjouterReclamationPageState extends State<AjouterReclamationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sujetController = TextEditingController();
  final TextEditingController _trajetController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  ReclamationType _type = ReclamationType.autre;

  @override
  void dispose() {
    _sujetController.dispose();
    _trajetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle réclamation'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ReclamationType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: ReclamationType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _type = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sujetController,
              decoration: const InputDecoration(
                labelText: 'Objet',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Veuillez renseigner l’objet de la réclamation.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _trajetController,
              decoration: const InputDecoration(
                labelText: 'Trajet concerné (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description détaillée',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Veuillez décrire précisément le problème.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _soumettre,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Soumettre la réclamation'),
            ),
          ],
        ),
      ),
    );
  }

  void _soumettre() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final nouvelleReclamation = Reclamation(
      id: DateTime.now().millisecondsSinceEpoch,
      type: _type,
      sujet: _sujetController.text.trim(),
      description: _descriptionController.text.trim(),
      trajet: (_trajetController.text.trim().isEmpty)
          ? 'Trajet non précisé'
          : _trajetController.text.trim(),
      date: DateTime.now(),
      status: ReclamationStatus.enAttente,
    );

    ReclamationService.instance.ajouter(nouvelleReclamation);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réclamation envoyée avec succès.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _typeLabel(ReclamationType type) {
    switch (type) {
      case ReclamationType.retard:
        return 'Retard';
      case ReclamationType.conducteur:
        return 'Conducteur';
      case ReclamationType.vehicule:
        return 'Véhicule';
      case ReclamationType.paiement:
        return 'Paiement';
      case ReclamationType.autre:
        return 'Autre';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final ReclamationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ReclamationStatus.enAttente:
        backgroundColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF8A6D1C);
        break;
      case ReclamationStatus.enCours:
        backgroundColor = const Color(0xFFE6F4FF);
        textColor = const Color(0xFF0057B8);
        break;
      case ReclamationStatus.resolue:
        backgroundColor = const Color(0xFFE8F7E9);
        textColor = const Color(0xFF1E7E34);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String get statusLabel {
    switch (status) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(color: AppColors.texte2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
