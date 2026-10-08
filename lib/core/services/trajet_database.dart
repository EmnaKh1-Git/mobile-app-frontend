// lib/core/services/trajet_database.dart
// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Base SQLite (sqflite) des trajets — même principe que
//  planning_database.dart : une base dédiée « trajets.db ».
//
//  Deux tables :
//    trajets  : un trajet par ligne
//    etapes   : les points de passage, liés à un trajet par trajet_id
//               (supprimés automatiquement avec le trajet : ON DELETE CASCADE)
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/trajet.dart';

class TrajetDatabase {
  TrajetDatabase._init();

  static final TrajetDatabase instance = TrajetDatabase._init();
  static Database? _database;

  static const String tableTrajets = 'trajets';
  static const String tableEtapes = 'etapes';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trajets.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      // Active les clés étrangères (nécessaire pour ON DELETE CASCADE)
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE $tableTrajets (
  id $idType,
  conducteur_id $intType,
  conducteur_nom $textType,
  conducteur_note $realType,
  ville_depart $textType,
  adresse_depart $textType,
  ville_arrivee $textType,
  adresse_arrivee $textType,
  date_depart $textType,
  duree_minutes $intType,
  distance_km $realType,
  vehicule $textType,
  capacite_vehicule $intType,
  places_totales $intType,
  places_disponibles $intType,
  prix_place $realType,
  bagages $intType,
  fumeur $intType,
  animaux $intType,
  reservation_auto $intType,
  description $textType,
  statut $textType,
  date_creation $textType
)
''');

    await db.execute('''
CREATE TABLE $tableEtapes (
  id $idType,
  trajet_id $intType,
  ville $textType,
  ordre $intType,
  prix $realType,
  FOREIGN KEY (trajet_id) REFERENCES $tableTrajets (id) ON DELETE CASCADE
)
''');

    // Index pour accélérer la recherche (départ, arrivée, date)
    await db.execute(
        'CREATE INDEX idx_trajets_recherche ON $tableTrajets (ville_depart, ville_arrivee, date_depart)');
    await db.execute(
        'CREATE INDEX idx_etapes_trajet ON $tableEtapes (trajet_id)');
  }

  // ---------- CRUD ----------

  /// Insère un trajet (et ses étapes) et le renvoie avec l'id attribué par SQLite
  Future<Trajet> create(Trajet trajet) async {
    final db = await instance.database;
    late int id;
    await db.transaction((txn) async {
      // toMap() n'inclut pas l'id quand il vaut 0 : SQLite le génère
      id = await txn.insert(tableTrajets, trajet.toMap());
      for (final e in trajet.etapes) {
        await txn.insert(tableEtapes, e.toMap(id));
      }
    });
    return trajet.copyWith(id: id);
  }

  /// Tous les trajets, triés par date de départ, avec leurs étapes
  Future<List<Trajet>> readAll() async {
    final db = await instance.database;
    final lignes = await db.query(tableTrajets, orderBy: 'date_depart ASC');
    final lignesEtapes = await db.query(tableEtapes, orderBy: 'ordre ASC');

    // Regroupe les étapes par trajet_id
    final etapesParTrajet = <int, List<Etape>>{};
    for (final m in lignesEtapes) {
      etapesParTrajet
          .putIfAbsent(m['trajet_id'] as int, () => <Etape>[])
          .add(Etape.fromMap(m));
    }

    return lignes
        .map((m) => Trajet.fromMap(m, etapes: etapesParTrajet[m['id'] as int]))
        .toList();
  }

  Future<Trajet?> readById(int id) async {
    final db = await instance.database;
    final res = await db.query(tableTrajets,
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    final etapes = await db.query(tableEtapes,
        where: 'trajet_id = ?', whereArgs: [id], orderBy: 'ordre ASC');
    return Trajet.fromMap(res.first,
        etapes: etapes.map((m) => Etape.fromMap(m)).toList());
  }

  /// Met à jour un trajet (places, statut, date…). Les étapes ne changent pas.
  Future<int> update(Trajet trajet) async {
    final db = await instance.database;
    return db.update(
      tableTrajets,
      trajet.toMap(),
      where: 'id = ?',
      whereArgs: [trajet.id],
    );
  }

  /// Supprime un trajet ; ses étapes sont supprimées par ON DELETE CASCADE
  Future<int> delete(int id) async {
    final db = await instance.database;
    return db.delete(tableTrajets, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableTrajets')) ??
        0;
  }

  /// Insère les données de démonstration si la table est vide
  Future<void> insertDemoData(List<Trajet> demo) async {
    if (await count() > 0) return;
    for (final t in demo) {
      await create(t);
    }
  }
}
