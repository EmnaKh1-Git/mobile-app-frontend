// lib/core/services/trajet_database.dart
// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Base SQLite (sqflite) des trajets — même principe que
//  planning_database.dart : une base dédiée « trajets.db ».
//
//  Trois tables :
//    trajets  : un trajet par ligne (+ coordonnées GPS et tracé depuis la v2)
//    etapes   : les points de passage, liés à un trajet par trajet_id
//               (supprimés automatiquement avec le trajet : ON DELETE CASCADE)
//    lieux    : lieux récents et enregistrés (écran « Indiquer votre itinéraire »)
//
//  Version 2 : ajout des colonnes carte et de la table lieux.
//  Les bases existantes (v1) sont migrées dans _upgradeDB sans perte.
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/lieu.dart';
import '../../models/trajet.dart';

class TrajetDatabase {
  TrajetDatabase._init();

  static final TrajetDatabase instance = TrajetDatabase._init();
  static Database? _database;

  static const String tableTrajets = 'trajets';
  static const String tableEtapes = 'etapes';
  static const String tableLieux = 'lieux';

  /// Nombre maximum de lieux récents (non enregistrés) conservés
  static const int maxLieuxRecents = 30;

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
      version: 2,
      // Active les clés étrangères (nécessaire pour ON DELETE CASCADE)
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Migration d'une base existante (les trajets déjà enregistrés sont gardés)
  Future<void> _upgradeDB(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      // v2 : positions GPS + tracé de la route, et lieux récents / enregistrés
      await db.execute('ALTER TABLE $tableTrajets ADD COLUMN lat_depart REAL');
      await db.execute('ALTER TABLE $tableTrajets ADD COLUMN lng_depart REAL');
      await db.execute('ALTER TABLE $tableTrajets ADD COLUMN lat_arrivee REAL');
      await db.execute('ALTER TABLE $tableTrajets ADD COLUMN lng_arrivee REAL');
      await db.execute(
          "ALTER TABLE $tableTrajets ADD COLUMN itineraire TEXT NOT NULL DEFAULT ''");
      await _creerTableLieux(db);
    }
  }

  Future<void> _creerTableLieux(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $tableLieux (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT NOT NULL,
  adresse TEXT NOT NULL,
  ville TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  enregistre INTEGER NOT NULL DEFAULT 0,
  date_utilisation TEXT NOT NULL
)
''');
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
  date_creation $textType,
  lat_depart REAL,
  lng_depart REAL,
  lat_arrivee REAL,
  lng_arrivee REAL,
  itineraire TEXT NOT NULL DEFAULT ''
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

    await _creerTableLieux(db);
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

  /// Insère les données de démonstration si la table est vide (ou force le rechargement)
  Future<void> insertDemoData(List<Trajet> demo, {bool force = false}) async {
    final db = await instance.database;
    if (force) {
      await db.delete(tableEtapes);
      await db.delete(tableTrajets);
    }
    if (await count() > 0) return;
    for (final t in demo) {
      await create(t);
    }
  }

  // ---------- LIEUX récents / enregistrés ----------

  /// Derniers lieux utilisés (onglet « Suggéré »)
  Future<List<Lieu>> lieuxRecents({int limite = 10}) async {
    final db = await instance.database;
    final res = await db.query(tableLieux,
        orderBy: 'date_utilisation DESC', limit: limite);
    return res.map((m) => Lieu.fromMap(m)).toList();
  }

  /// Lieux marqués d'un signet (onglet « Enregistré »)
  Future<List<Lieu>> lieuxEnregistres() async {
    final db = await instance.database;
    final res = await db.query(tableLieux,
        where: 'enregistre = 1', orderBy: 'nom COLLATE NOCASE');
    return res.map((m) => Lieu.fromMap(m)).toList();
  }

  /// Ajoute le lieu aux récents, ou met sa date à jour s'il existe déjà
  Future<Lieu> memoriserLieu(Lieu lieu) async {
    final db = await instance.database;
    final maintenant = DateTime.now().toIso8601String();
    final existant = await _trouverLieu(db, lieu);
    if (existant != null) {
      await db.update(tableLieux, {'date_utilisation': maintenant},
          where: 'id = ?', whereArgs: [existant.id]);
      return existant;
    }
    final id = await db.insert(tableLieux, lieu.toMap()..remove('id'));
    // On ne garde que les lieux récents les plus utilisés (+ tous les favoris)
    await db.rawDelete(
        'DELETE FROM $tableLieux WHERE enregistre = 0 AND id NOT IN '
        '(SELECT id FROM $tableLieux ORDER BY date_utilisation DESC LIMIT $maxLieuxRecents)');
    return lieu.copyWith(id: id);
  }

  /// Ajoute ou retire le lieu des favoris ; renvoie le lieu mis à jour
  Future<Lieu> basculerLieuEnregistre(Lieu lieu) async {
    final db = await instance.database;
    final existant = await _trouverLieu(db, lieu) ?? await memoriserLieu(lieu);
    final nouveau = !existant.enregistre;
    await db.update(tableLieux, {'enregistre': nouveau ? 1 : 0},
        where: 'id = ?', whereArgs: [existant.id]);
    return existant.copyWith(enregistre: nouveau);
  }

  Future<Lieu?> _trouverLieu(Database db, Lieu lieu) async {
    final res = lieu.id != null
        ? await db.query(tableLieux,
            where: 'id = ?', whereArgs: [lieu.id], limit: 1)
        : await db.query(tableLieux,
            where: 'nom = ? AND ABS(lat - ?) < 0.0005 AND ABS(lng - ?) < 0.0005',
            whereArgs: [lieu.nom, lieu.lat, lieu.lng],
            limit: 1);
    return res.isEmpty ? null : Lieu.fromMap(res.first);
  }
}
