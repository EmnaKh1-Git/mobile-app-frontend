// lib/core/services/planning_database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/planning.dart';

class PlanningDatabase {
  static final PlanningDatabase instance = PlanningDatabase._init();
  static Database? _database;

  PlanningDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('planning.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE planning ( 
  id $idType, 
  lieuDepart $textType,
  destination $textType,
  date $textType,
  heure $textType,
  statut $textType,
  rappelActif $intType,
  rappelDelai $intType,
  role $textType,
  placesDisponibles $intType
  )
''');
  }

  // Méthode pour insérer un trajet
  Future<Planning> create(Planning planning) async {
    final db = await instance.database;
    final id = await db.insert('planning', planning.toMap());
    return Planning(
      id: id,
      lieuDepart: planning.lieuDepart,
      destination: planning.destination,
      date: planning.date,
      heure: planning.heure,
      statut: planning.statut,
      rappelActif: planning.rappelActif,
      rappelDelai: planning.rappelDelai,
      role: planning.role,
      placesDisponibles: planning.placesDisponibles,
    );
  }

  // Méthode pour lire tous les trajets
  Future<List<Planning>> readAllPlannings() async {
    final db = await instance.database;
    final result = await db.query('planning', orderBy: 'date ASC');
    return result.map((json) => Planning.fromMap(json)).toList();
  }

  // Méthode pour mettre à jour
  Future<int> update(Planning planning) async {
    final db = await instance.database;
    return db.update(
      'planning',
      planning.toMap(),
      where: 'id = ?',
      whereArgs: [planning.id],
    );
  }

  // Méthode pour supprimer
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'planning',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<void> insertDemoData() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM planning'));
    if (count == 0) {
      await create(Planning(
        lieuDepart: 'Mnihla',
        destination: 'Campus El Manar',
        date: 'Lun. 5 oct.',
        heure: '07:30',
        statut: 'À venir',
        role: 'Conducteur',
        placesDisponibles: 2,
      ));
      await create(Planning(
        lieuDepart: 'Campus El Manar',
        destination: 'Mnihla',
        date: 'Ven. 2 oct.',
        heure: '17:30',
        statut: 'À venir',
        role: 'Conducteur',
        placesDisponibles: 0,
      ));
      await create(Planning(
        lieuDepart: 'Tunis',
        destination: 'Sfax',
        date: 'Jeu. 8 oct.',
        heure: '07:00',
        statut: 'À venir',
        role: 'Passager',
        placesDisponibles: 0,
      ));
    }
  }
}