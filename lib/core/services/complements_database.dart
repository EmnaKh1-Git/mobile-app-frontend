// lib/core/services/complements_database.dart
// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Base SQLite (sqflite) « complements.db » — même principe que
//  discussion_database.dart. La table « trajets » n'est pas modifiée
//  (elle est partagée avec les autres modules) : ce qui s'ajoute aux
//  trajets est enregistré ici.
//
//  Trois tables :
//    notifications_trajet : le centre de notifications
//    alertes_trajet       : les alertes de recherche
//    options_trajet       : série d'un trajet régulier et option
//                           « Entre filles », liées par trajet_id
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/notification_trajet.dart';

class ComplementsDatabase {
  ComplementsDatabase._init();

  static final ComplementsDatabase instance = ComplementsDatabase._init();
  static Database? _database;

  static const String tableNotifications = 'notifications_trajet';
  static const String tableAlertes = 'alertes_trajet';
  static const String tableOptions = 'options_trajet';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('complements.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    return openDatabase(join(dbPath, fileName), version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE $tableNotifications (
  id $idType,
  cle TEXT NOT NULL UNIQUE,
  type $textType,
  titre $textType,
  texte $textType,
  trajet_id INTEGER,
  date $textType,
  lue $intType
)
''');

    await db.execute('''
CREATE TABLE $tableAlertes (
  id $idType,
  ville_depart $textType,
  ville_arrivee $textType,
  jour TEXT,
  heure INTEGER,
  moment TEXT,
  places $intType,
  date_creation $textType
)
''');

    await db.execute('''
CREATE TABLE $tableOptions (
  trajet_id INTEGER PRIMARY KEY,
  serie_id TEXT,
  entre_filles $intType
)
''');
  }

  // ---------- Notifications ----------

  Future<List<NotificationTrajet>> lireNotifications() async {
    final db = await instance.database;
    final res = await db.query(tableNotifications, orderBy: 'date DESC');
    return res.map(NotificationTrajet.fromMap).toList();
  }

  /// Insère la notification (ignorée si sa clé existe déjà) et la
  /// renvoie avec l'id attribué par SQLite
  Future<NotificationTrajet> ajouterNotification(NotificationTrajet n) async {
    final db = await instance.database;
    final id = await db.insert(tableNotifications, n.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id > 0 ? n.copyWith(id: id) : n;
  }

  Future<void> marquerLues(List<String> cles) async {
    if (cles.isEmpty) return;
    final db = await instance.database;
    await db.update(tableNotifications, {'lue': 1},
        where: 'cle IN (${List.filled(cles.length, '?').join(', ')})',
        whereArgs: cles);
  }

  // ---------- Alertes ----------

  Future<List<AlerteTrajet>> lireAlertes() async {
    final db = await instance.database;
    final res = await db.query(tableAlertes, orderBy: 'date_creation DESC');
    return res.map(AlerteTrajet.fromMap).toList();
  }

  Future<AlerteTrajet> ajouterAlerte(AlerteTrajet a) async {
    final db = await instance.database;
    final id = await db.insert(tableAlertes, a.toMap());
    return a.copyWith(id: id);
  }

  Future<int> supprimerAlerte(int id) async {
    final db = await instance.database;
    return db.delete(tableAlertes, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Options des trajets ----------

  /// trajet_id → série et option « Entre filles »
  Future<Map<int, ({String? serieId, bool entreFilles})>> lireOptions() async {
    final db = await instance.database;
    final res = await db.query(tableOptions);
    return {
      for (final m in res)
        m['trajet_id'] as int: (
          serieId: m['serie_id'] as String?,
          entreFilles: (m['entre_filles'] as int? ?? 0) == 1,
        ),
    };
  }

  Future<void> enregistrerOptions(
      int trajetId, String? serieId, bool entreFilles) async {
    final db = await instance.database;
    await db.insert(
      tableOptions,
      {
        'trajet_id': trajetId,
        'serie_id': serieId,
        'entre_filles': entreFilles ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Efface les options et les notifications d'un trajet supprimé
  Future<void> supprimerTrajet(int trajetId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in [tableOptions, tableNotifications]) {
        await txn.delete(table, where: 'trajet_id = ?', whereArgs: [trajetId]);
      }
    });
  }
}
