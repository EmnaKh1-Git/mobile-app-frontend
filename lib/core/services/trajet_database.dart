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

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lieu.dart';
import '../../models/trajet.dart';
import 'synchro_supabase.dart';

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
        "ALTER TABLE $tableTrajets ADD COLUMN itineraire TEXT NOT NULL DEFAULT ''",
      );
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
      'CREATE INDEX idx_trajets_recherche ON $tableTrajets (ville_depart, ville_arrivee, date_depart)',
    );
    await db.execute(
      'CREATE INDEX idx_etapes_trajet ON $tableEtapes (trajet_id)',
    );

    await _creerTableLieux(db);
  }

  // ---------- Synchronisation Supabase ----------

  static const _trajets = TableSynchro(
    tableTrajets,
    colonnes: [
      'id', 'conducteur_id', 'conducteur_nom', 'conducteur_note',
      'ville_depart', 'adresse_depart', 'ville_arrivee', 'adresse_arrivee',
      'date_depart', 'duree_minutes', 'distance_km', 'vehicule',
      'capacite_vehicule', 'places_totales', 'places_disponibles',
      'prix_place', 'bagages', 'fumeur', 'animaux', 'reservation_auto',
      'description', 'statut', 'date_creation', 'lat_depart', 'lng_depart',
      'lat_arrivee', 'lng_arrivee', 'itineraire',
    ],
    dates: {'date_depart', 'date_creation'},
    booleens: {'bagages', 'fumeur', 'animaux', 'reservation_auto'},
    reels: {
      'conducteur_note', 'distance_km', 'prix_place', 'lat_depart',
      'lng_depart', 'lat_arrivee', 'lng_arrivee',
    },
  );

  static const _etapes = TableSynchro(
    tableEtapes,
    distante: 'trajet_etapes',
    colonnes: ['trajet_id', 'ville', 'ordre', 'prix'],
    reels: {'prix'},
  );

  /// Remplace la copie locale par les trajets (et étapes) de Supabase.
  /// Renvoie false si Supabase est injoignable.
  Future<bool> _miroir(Database db) async {
    final distants = await SynchroSupabase.lire(_trajets,
        select: '*, trajet_etapes(*)');
    if (distants == null) return false;
    try {
      await db.transaction((txn) async {
        await txn.delete(tableEtapes);
        await txn.delete(tableTrajets);
        for (final row in distants) {
          await txn.insert(tableTrajets, _trajets.versLocal(row));
          for (final e in (row['trajet_etapes'] as List?) ?? const []) {
            await txn.insert(
                tableEtapes, _etapes.versLocal(Map<String, dynamic>.from(e)));
          }
        }
      });
      return true;
    } catch (error) {
      debugPrint('[TrajetDatabase] Copie locale Supabase impossible : $error');
      return false;
    }
  }

  // ---------- CRUD ----------

  /// Insère un trajet (et ses étapes) et le renvoie avec l'id attribué
  /// par Supabase (ou par SQLite hors connexion)
  Future<Trajet> create(Trajet trajet) async {
    final db = await instance.database;
    var id = trajet.id;
    final idDistant = await SynchroSupabase.inserer(_trajets, trajet.toMap());
    if (idDistant != null) {
      id = idDistant;
      for (final e in trajet.etapes) {
        await SynchroSupabase.inserer(_etapes, e.toMap(id));
      }
    }
    await db.transaction((txn) async {
      // toMap() n'inclut pas l'id quand il vaut 0 : SQLite le génère
      final localMap = trajet.toMap();
      if (id > 0) localMap['id'] = id;
      id = await txn.insert(tableTrajets, localMap,
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final e in trajet.etapes) {
        await txn.insert(tableEtapes, e.toMap(id));
      }
    });
    return trajet.copyWith(id: id);
  }

  /// Tous les trajets, triés par date de départ, avec leurs étapes.
  /// La copie locale est d'abord mise à jour depuis Supabase.
  Future<List<Trajet>> readAll() async {
    final db = await instance.database;
    await _miroir(db);
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
    final res = await db.query(
      tableTrajets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final etapes = await db.query(
      tableEtapes,
      where: 'trajet_id = ?',
      whereArgs: [id],
      orderBy: 'ordre ASC',
    );
    return Trajet.fromMap(
      res.first,
      etapes: etapes.map((m) => Etape.fromMap(m)).toList(),
    );
  }

  /// Met à jour un trajet (places, statut, date…). Les étapes ne changent pas.
  Future<int> update(Trajet trajet) async {
    final db = await instance.database;
    final updated = await db.update(
      tableTrajets,
      trajet.toMap(),
      where: 'id = ?',
      whereArgs: [trajet.id],
    );
    await SynchroSupabase.modifier(_trajets, trajet.id, trajet.toMap());
    return updated;
  }

  /// Supprime un trajet ; ses étapes sont supprimées par ON DELETE CASCADE
  /// (dans SQLite comme dans Supabase)
  Future<int> delete(int id) async {
    final db = await instance.database;
    final deleted = await db.delete(
      tableTrajets,
      where: 'id = ?',
      whereArgs: [id],
    );
    await SynchroSupabase.supprimer(_trajets, 'id', id);
    return deleted;
  }

  Future<int> count() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableTrajets'),
        ) ??
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
    // Supabase contient déjà des trajets (base remplie par supabase/seed.sql
    // ou par d'autres utilisateurs) : pas de démonstration
    if (!force) {
      final distants = await SynchroSupabase.lire(_trajets, select: 'id');
      if (distants != null && distants.isNotEmpty) return;
    }
    for (final t in demo) {
      await create(t);
    }
  }

  // ---------- LIEUX récents / enregistrés ----------

  /// Derniers lieux utilisés (onglet « Suggéré »)
  Future<List<Lieu>> lieuxRecents({int limite = 10}) async {
    final db = await instance.database;
    try {
      final remote = await Supabase.instance.client
          .from(tableLieux)
          .select()
          .order('date_utilisation', ascending: false)
          .limit(limite);
      return remote
          .map((row) => Lieu.fromMap(_localLieuMap(Map<String, dynamic>.from(row))))
          .toList();
    } catch (error) {
      debugPrint('[TrajetDatabase] Lecture des lieux Supabase impossible : $error');
    }
    final res = await db.query(
      tableLieux,
      orderBy: 'date_utilisation DESC',
      limit: limite,
    );
    return res.map((m) => Lieu.fromMap(m)).toList();
  }

  /// Lieux marqués d'un signet (onglet « Enregistré »)
  Future<List<Lieu>> lieuxEnregistres() async {
    final db = await instance.database;
    try {
      final remote = await Supabase.instance.client
          .from(tableLieux)
          .select()
          .eq('enregistre', true)
          .order('nom');
      return remote
          .map((row) => Lieu.fromMap(_localLieuMap(Map<String, dynamic>.from(row))))
          .toList();
    } catch (error) {
      debugPrint('[TrajetDatabase] Lecture des favoris Supabase impossible : $error');
    }
    final res = await db.query(
      tableLieux,
      where: 'enregistre = 1',
      orderBy: 'nom COLLATE NOCASE',
    );
    return res.map((m) => Lieu.fromMap(m)).toList();
  }

  /// Ajoute le lieu aux récents, ou met sa date à jour s'il existe déjà
  Future<Lieu> memoriserLieu(Lieu lieu) async {
    final db = await instance.database;
    final maintenant = DateTime.now().toIso8601String();
    final existant = await _trouverLieu(db, lieu);
    if (existant != null) {
      await db.update(
        tableLieux,
        {'date_utilisation': maintenant},
        where: 'id = ?',
        whereArgs: [existant.id],
      );
      try {
        await Supabase.instance.client
            .from(tableLieux)
            .update({'date_utilisation': maintenant})
            .eq('id', existant.id!);
      } catch (error) {
        debugPrint('[TrajetDatabase] Mise à jour du lieu impossible : $error');
      }
      return existant;
    }
    final id = await db.insert(tableLieux, lieu.toMap()..remove('id'));
    try {
      final remote = await Supabase.instance.client
          .from(tableLieux)
          .insert(_remoteLieuMap(lieu))
          .select('id')
          .single();
      return lieu.copyWith(id: (remote['id'] as num).toInt());
    } catch (error) {
      debugPrint('[TrajetDatabase] Enregistrement du lieu impossible : $error');
    }
    // On ne garde que les lieux récents les plus utilisés (+ tous les favoris)
    await db.rawDelete(
      'DELETE FROM $tableLieux WHERE enregistre = 0 AND id NOT IN '
      '(SELECT id FROM $tableLieux ORDER BY date_utilisation DESC LIMIT $maxLieuxRecents)',
    );
    return lieu.copyWith(id: id);
  }

  /// Ajoute ou retire le lieu des favoris ; renvoie le lieu mis à jour
  Future<Lieu> basculerLieuEnregistre(Lieu lieu) async {
    final db = await instance.database;
    final existant = await _trouverLieu(db, lieu) ?? await memoriserLieu(lieu);
    final nouveau = !existant.enregistre;
    await db.update(
      tableLieux,
      {'enregistre': nouveau ? 1 : 0},
      where: 'id = ?',
      whereArgs: [existant.id],
    );
    try {
      await Supabase.instance.client
          .from(tableLieux)
          .update({'enregistre': nouveau})
          .eq('id', existant.id!);
    } catch (error) {
      debugPrint('[TrajetDatabase] Mise à jour du favori impossible : $error');
    }
    return existant.copyWith(enregistre: nouveau);
  }

  Map<String, dynamic> _remoteLieuMap(Lieu lieu) => {
        'nom': lieu.nom,
        'adresse': lieu.adresse,
        'ville': lieu.ville,
        'lat': lieu.lat,
        'lng': lieu.lng,
        'enregistre': lieu.enregistre,
        'date_utilisation': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> _localLieuMap(Map<String, dynamic> map) => {
        ...map,
        'enregistre': map['enregistre'] == true ? 1 : map['enregistre'],
      };

  Future<Lieu?> _trouverLieu(Database db, Lieu lieu) async {
    final res = lieu.id != null
        ? await db.query(
            tableLieux,
            where: 'id = ?',
            whereArgs: [lieu.id],
            limit: 1,
          )
        : await db.query(
            tableLieux,
            where:
                'nom = ? AND ABS(lat - ?) < 0.0005 AND ABS(lng - ?) < 0.0005',
            whereArgs: [lieu.nom, lieu.lat, lieu.lng],
            limit: 1,
          );
    return res.isEmpty ? null : Lieu.fromMap(res.first);
  }
}
