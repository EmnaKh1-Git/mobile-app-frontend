// lib/core/services/discussion_database.dart
// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Base SQLite (sqflite) des discussions de trajet — même principe
//  que trajet_database.dart : une base dédiée « discussions.db ».
//
//  Quatre tables, liées à un trajet par trajet_id :
//    passagers_trajet    : qui a réservé, combien de places, présence
//    messages_trajet     : les messages de la discussion du trajet
//    lectures_discussion : jusqu'où chaque utilisateur a lu (non lus)
//    evaluations_trajet  : les notes données après le trajet
//
//  Version 2 : présence des passagers et évaluations (migration
//  sans perte des bases v1 dans _upgradeDB).
//
//  Les trajets sont dans une autre base : quand un trajet est
//  supprimé, supprimerTrajet() efface aussi sa discussion.
//
//  Synchronisation Supabase (synchro_supabase.dart) : les mêmes
//  tables existent dans Supabase (supabase/schema.sql). Les lectures
//  recopient Supabase dans SQLite, les écritures vont dans les deux.
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/discussion_trajet.dart';
import 'synchro_supabase.dart';

class DiscussionDatabase {
  DiscussionDatabase._init();

  static final DiscussionDatabase instance = DiscussionDatabase._init();
  static Database? _database;

  static const String tablePassagers = 'passagers_trajet';
  static const String tableMessages = 'messages_trajet';
  static const String tableLectures = 'lectures_discussion';
  static const String tableEvaluations = 'evaluations_trajet';

  static const _passagers = TableSynchro(
    tablePassagers,
    colonnes: [
      'id', 'trajet_id', 'passager_id', 'nom', 'places',
      'date_reservation', 'presence',
    ],
    dates: {'date_reservation'},
  );
  static const _messages = TableSynchro(
    tableMessages,
    colonnes: [
      'id', 'trajet_id', 'auteur_id', 'auteur_nom', 'texte', 'type', 'date',
    ],
    dates: {'date'},
  );
  static const _lectures = TableSynchro(
    tableLectures,
    colonnes: ['trajet_id', 'user_id', 'lu_jusqu_a'],
    dates: {'lu_jusqu_a'},
  );
  static const _evaluations = TableSynchro(
    tableEvaluations,
    colonnes: [
      'id', 'trajet_id', 'auteur_id', 'auteur_nom', 'cible_id', 'cible_nom',
      'note', 'commentaire', 'date',
    ],
    dates: {'date'},
  );

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('discussions.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, fileName),
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Migration d'une base existante (passagers et messages gardés)
  Future<void> _upgradeDB(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      await db.execute(
          "ALTER TABLE $tablePassagers ADD COLUMN presence TEXT NOT NULL DEFAULT 'inconnue'");
      await _creerTableEvaluations(db);
    }
  }

  Future<void> _creerTableEvaluations(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $tableEvaluations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trajet_id INTEGER NOT NULL,
  auteur_id INTEGER NOT NULL,
  auteur_nom TEXT NOT NULL,
  cible_id INTEGER NOT NULL,
  cible_nom TEXT NOT NULL,
  note INTEGER NOT NULL,
  commentaire TEXT NOT NULL,
  date TEXT NOT NULL,
  UNIQUE (trajet_id, auteur_id, cible_id)
)
''');
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE $tablePassagers (
  id $idType,
  trajet_id $intType,
  passager_id $intType,
  nom $textType,
  places $intType,
  date_reservation $textType,
  presence TEXT NOT NULL DEFAULT 'inconnue'
)
''');

    await db.execute('''
CREATE TABLE $tableMessages (
  id $idType,
  trajet_id $intType,
  auteur_id $intType,
  auteur_nom $textType,
  texte $textType,
  type $textType,
  date $textType
)
''');

    await db.execute('''
CREATE TABLE $tableLectures (
  trajet_id $intType,
  user_id $intType,
  lu_jusqu_a $textType,
  PRIMARY KEY (trajet_id, user_id)
)
''');

    await db.execute(
        'CREATE INDEX idx_passagers_trajet ON $tablePassagers (trajet_id)');
    await db.execute(
        'CREATE INDEX idx_messages_trajet ON $tableMessages (trajet_id, date)');

    await _creerTableEvaluations(db);
  }

  // ---------- Passagers ----------

  Future<List<PassagerTrajet>> lirePassagers() async {
    final db = await instance.database;
    await SynchroSupabase.miroir(db, _passagers);
    final res = await db.query(tablePassagers, orderBy: 'date_reservation ASC');
    return res.map(PassagerTrajet.fromMap).toList();
  }

  /// Insère la réservation et la renvoie avec l'id attribué
  /// (par Supabase, ou par SQLite hors connexion)
  Future<PassagerTrajet> ajouterPassager(PassagerTrajet p) async {
    final db = await instance.database;
    final ligne = p.toMap();
    final idDistant = await SynchroSupabase.inserer(_passagers, ligne);
    if (idDistant != null) ligne['id'] = idDistant;
    final id = await db.insert(tablePassagers, ligne,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return p.copyWith(id: id);
  }

  Future<int> modifierPassager(PassagerTrajet p) async {
    final db = await instance.database;
    final res = await db.update(tablePassagers, p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
    if (p.id != null) {
      await SynchroSupabase.modifier(_passagers, p.id!, p.toMap());
    }
    return res;
  }

  Future<int> supprimerPassager(int id) async {
    final db = await instance.database;
    final res =
        await db.delete(tablePassagers, where: 'id = ?', whereArgs: [id]);
    await SynchroSupabase.supprimer(_passagers, 'id', id);
    return res;
  }

  // ---------- Messages ----------

  Future<List<MessageTrajet>> lireMessages() async {
    final db = await instance.database;
    await SynchroSupabase.miroir(db, _messages);
    final res = await db.query(tableMessages, orderBy: 'date ASC');
    return res.map(MessageTrajet.fromMap).toList();
  }

  Future<MessageTrajet> ajouterMessage(MessageTrajet m) async {
    final db = await instance.database;
    final ligne = m.toMap();
    final idDistant = await SynchroSupabase.inserer(_messages, ligne);
    if (idDistant != null) ligne['id'] = idDistant;
    final id = await db.insert(tableMessages, ligne,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return m.copyWith(id: id);
  }

  // ---------- Lectures (messages non lus) ----------

  /// trajet_id → date du dernier message lu par [userId]
  Future<Map<int, DateTime>> lireLectures(int userId) async {
    final db = await instance.database;
    final distantes = await SynchroSupabase.lire(_lectures,
        colonne: 'user_id', valeur: userId);
    if (distantes != null) {
      for (final l in distantes) {
        await db.insert(tableLectures, _lectures.versLocal(l),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    final res = await db
        .query(tableLectures, where: 'user_id = ?', whereArgs: [userId]);
    return {
      for (final m in res)
        m['trajet_id'] as int: DateTime.parse(m['lu_jusqu_a'] as String),
    };
  }

  Future<void> enregistrerLecture(int trajetId, int userId, DateTime date) async {
    final db = await instance.database;
    final ligne = {
      'trajet_id': trajetId,
      'user_id': userId,
      'lu_jusqu_a': date.toIso8601String(),
    };
    await db.insert(tableLectures, ligne,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await SynchroSupabase.upsert(_lectures, ligne,
        conflit: 'trajet_id,user_id');
  }

  // ---------- Évaluations ----------

  Future<List<EvaluationTrajet>> lireEvaluations() async {
    final db = await instance.database;
    await SynchroSupabase.miroir(db, _evaluations);
    final res = await db.query(tableEvaluations, orderBy: 'date DESC');
    return res.map(EvaluationTrajet.fromMap).toList();
  }

  Future<EvaluationTrajet> ajouterEvaluation(EvaluationTrajet e) async {
    final db = await instance.database;
    final ligne = e.toMap();
    final idDistant = await SynchroSupabase.inserer(_evaluations, ligne);
    if (idDistant != null) ligne['id'] = idDistant;
    final id = await db.insert(tableEvaluations, ligne,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return e.copyWith(id: id);
  }

  /// Efface les passagers, messages, lectures et évaluations d'un trajet supprimé
  Future<void> supprimerTrajet(int trajetId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in [
        tablePassagers,
        tableMessages,
        tableLectures,
        tableEvaluations,
      ]) {
        await txn.delete(table, where: 'trajet_id = ?', whereArgs: [trajetId]);
      }
    });
    for (final t in [_passagers, _messages, _lectures, _evaluations]) {
      await SynchroSupabase.supprimer(t, 'trajet_id', trajetId);
    }
  }
}
