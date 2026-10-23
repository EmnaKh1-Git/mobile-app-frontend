import 'package:sqflite/sqflite.dart';
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
    return result.map((json) => Planning.fromMap(json)).toList();
  }

  Future<int> update(Planning planning) async {
    final db = await database;
    return db.update(
      'planning',
      planning.toMap(),
      where: 'id = ?',
      whereArgs: [planning.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete('planning', where: 'id = ?', whereArgs: [id]);
  }
}