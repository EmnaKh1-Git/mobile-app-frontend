import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/planning.dart';
import 'database_service.dart'; // <-- On importe le service commun

class PlanningDatabase {
  static final PlanningDatabase instance = PlanningDatabase._init();
  PlanningDatabase._init();

  // On utilise TOUJOURS la base de données commune
  Future<Database> get database async {
    return await DatabaseService.instance.database;
  }

  Future<Planning> create(Planning planning) async {
    final db = await database;
    final id = await db.insert('planning', planning.toMap());
    try {
      await Supabase.instance.client
          .from('planning')
          .upsert(_remoteMap(planning, id), onConflict: 'id');
    } catch (error) {
      // SQLite remains the offline cache; the next read can retry remotely.
      debugPrint(
        '[PlanningDatabase] Synchronisation Supabase impossible : $error',
      );
    }
    return Planning(
      id: id,
      lieuDepart: planning.lieuDepart,
      destination: planning.destination,
      destinationLat: planning.destinationLat,
      destinationLng: planning.destinationLng,
      date: planning.date,
      heure: planning.heure,
      statut: planning.statut,
      rappelActif: planning.rappelActif,
      rappelDelai: planning.rappelDelai,
      role: planning.role,
      placesDisponibles: planning.placesDisponibles,
    );
  }

  Future<List<Planning>> readAllPlannings() async {
    final db = await database;
    final result = await db.query('planning', orderBy: 'heure ASC');
    final local = result.map((json) => Planning.fromMap(json)).toList();
    try {
      final remote = await Supabase.instance.client
          .from('planning')
          .select()
          .order('heure');
      for (final row in remote) {
        final planning = Planning.fromMap(_localMap(row));
        await db.insert(
          'planning',
          planning.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return remote.map((row) => Planning.fromMap(_localMap(row))).toList();
    } catch (error) {
      debugPrint('[PlanningDatabase] Lecture Supabase impossible : $error');
      return local;
    }
  }

  Future<int> update(Planning planning) async {
    final db = await database;
    final updated = await db.update(
      'planning',
      planning.toMap(),
      where: 'id = ?',
      whereArgs: [planning.id],
    );
    try {
      await Supabase.instance.client
          .from('planning')
          .upsert(_remoteMap(planning, planning.id), onConflict: 'id');
    } catch (error) {
      debugPrint('[PlanningDatabase] Mise à jour Supabase impossible : $error');
    }
    return updated;
  }

  Future<int> delete(int id) async {
    final db = await database;
    final deleted = await db.delete(
      'planning',
      where: 'id = ?',
      whereArgs: [id],
    );
    try {
      await Supabase.instance.client.from('planning').delete().eq('id', id);
    } catch (error) {
      debugPrint('[PlanningDatabase] Suppression Supabase impossible : $error');
    }
    return deleted;
  }

  Map<String, dynamic> _remoteMap(Planning planning, int? id) => {
    'id': ?id,
    'lieuDepart': planning.lieuDepart,
    'lieuDepartLat': planning.lieuDepartLat,
    'lieuDepartLng': planning.lieuDepartLng,
    'destination': planning.destination,
    'destinationLat': planning.destinationLat,
    'destinationLng': planning.destinationLng,
    'date': planning.date,
    'heure': planning.heure,
    'statut': planning.statut,
    'rappelActif': planning.rappelActif,
    'rappelDelai': planning.rappelDelai,
    'role': planning.role,
    'placesDisponibles': planning.placesDisponibles,
  };

  Map<String, dynamic> _localMap(Map<String, dynamic> row) => {
    ...row,
    'rappelActif': row['rappelActif'] == true ? 1 : 0,
  };
}
