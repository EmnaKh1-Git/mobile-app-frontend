import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';

import '../models/reclamation.dart';

class ReclamationService extends ChangeNotifier {
  ReclamationService._() {
    _loadPersisted();
  }

  static final ReclamationService instance = ReclamationService._();

  final List<Reclamation> _reclamations = [
    Reclamation(
      id: 1,
      type: ReclamationType.retard,
      sujet: 'Retard au départ',
      description: 'Le conducteur est arrivé avec 20 minutes de retard au point de rendez-vous et n’a pas informé les passagers à temps.',
      trajet: 'Tunis → Sousse',
      date: DateTime(2026, 9, 28, 17, 30),
      status: ReclamationStatus.enCours,
    ),
    Reclamation(
      id: 2,
      type: ReclamationType.vehicule,
      sujet: 'État du véhicule',
      description: 'La climatisation ne fonctionnait pas durant le trajet, ce qui a rendu le voyage très inconfortable.',
      trajet: 'Bizerte → Tunis',
      date: DateTime(2026, 9, 18, 8, 15),
      status: ReclamationStatus.resolue,
    ),
  ];

  Future<void> _loadPersisted() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('reclamations', orderBy: 'date DESC');
    for (final row in rows) {
      final reclamation = _fromMap(row);
      final index = _reclamations.indexWhere(
        (item) => item.id == reclamation.id,
      );
      if (index == -1) {
        _reclamations.add(reclamation);
      } else {
        _reclamations[index] = reclamation;
      }
    }
    notifyListeners();
  }

  List<Reclamation> get reclamations => List.unmodifiable(_reclamations);

  List<String> get categoriesSysteme {
    final counts = <String, int>{};
    for (final reclamation in _reclamations) {
      final category = reclamation.autreCategorie?.trim();
      if (reclamation.type == ReclamationType.autre &&
          category != null &&
          category.isNotEmpty) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return counts.entries
        .where((entry) => entry.value >= 5)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  void ajouter(Reclamation reclamation) {
    _reclamations.insert(0, reclamation);
    _save(reclamation);
    notifyListeners();
  }

  void mettreAJourStatut(int id, ReclamationStatus nouveauStatut) {
    final index = _reclamations.indexWhere(
      (reclamation) => reclamation.id == id,
    );
    if (index == -1) {
      return;
    }

    final reclamation = _reclamations[index];
    _reclamations[index] = Reclamation(
      id: reclamation.id,
      type: reclamation.type,
      sujet: reclamation.sujet,
      description: reclamation.description,
      trajet: reclamation.trajet,
      date: reclamation.date,
      status: nouveauStatut,
      autreCategorie: reclamation.autreCategorie,
      imagePath: reclamation.imagePath,
      audioPath: reclamation.audioPath,
      aiConseil: reclamation.aiConseil,
      responses: reclamation.responses,
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  void ajouterReponse(int id, String message) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) return;

    final index = _reclamations.indexWhere(
      (reclamation) => reclamation.id == id,
    );
    if (index == -1) return;

    final reclamation = _reclamations[index];
    _reclamations[index] = Reclamation(
      id: reclamation.id,
      type: reclamation.type,
      sujet: reclamation.sujet,
      description: reclamation.description,
      trajet: reclamation.trajet,
      date: reclamation.date,
      status: reclamation.status,
      autreCategorie: reclamation.autreCategorie,
      imagePath: reclamation.imagePath,
      audioPath: reclamation.audioPath,
      aiConseil: reclamation.aiConseil,
      responses: [
        ...reclamation.responses,
        ReclamationResponse(message: normalizedMessage, date: DateTime.now()),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  Future<void> _save(Reclamation reclamation) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'reclamations',
      _toMap(reclamation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toMap(Reclamation reclamation) => {
    'id': reclamation.id,
    'type': reclamation.type.name,
    'sujet': reclamation.sujet,
    'description': reclamation.description,
    'trajet': reclamation.trajet,
    'date': reclamation.date.toIso8601String(),
    'status': reclamation.status.name,
    'autreCategorie': reclamation.autreCategorie,
    'imagePath': reclamation.imagePath,
    'audioPath': reclamation.audioPath,
    'aiConseil': reclamation.aiConseil,
    'responses': jsonEncode(
      reclamation.responses
          .map(
            (response) => {
              'message': response.message,
              'date': response.date.toIso8601String(),
            },
          )
          .toList(),
    ),
  };

  Reclamation _fromMap(Map<String, Object?> map) {
    final responseList =
        (jsonDecode(map['responses'] as String? ?? '[]') as List)
            .whereType<Map>()
            .map(
              (item) => ReclamationResponse(
                message: item['message'] as String? ?? '',
                date: DateTime.parse(item['date'] as String),
              ),
            )
            .toList();
    return Reclamation(
      id: map['id'] as int,
      type: ReclamationType.values.byName(map['type'] as String),
      sujet: map['sujet'] as String,
      description: map['description'] as String,
      trajet: map['trajet'] as String,
      date: DateTime.parse(map['date'] as String),
      status: ReclamationStatus.values.byName(map['status'] as String),
      autreCategorie: map['autreCategorie'] as String?,
      imagePath: map['imagePath'] as String?,
      audioPath: map['audioPath'] as String?,
      aiConseil: map['aiConseil'] as String?,
      responses: responseList,
    );
  }
}
