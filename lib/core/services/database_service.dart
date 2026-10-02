import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'covoiturage_etudiant.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telephone TEXT,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trajets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conducteur_id INTEGER NOT NULL,
        ville_depart TEXT NOT NULL,
        ville_arrivee TEXT NOT NULL,
        date_depart TEXT NOT NULL,
        vehicule TEXT,
        places_totales INTEGER NOT NULL,
        places_disponibles INTEGER NOT NULL,
        FOREIGN KEY (conducteur_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE recommandations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        trajet_id INTEGER NOT NULL,
        score REAL,
        statut TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (trajet_id) REFERENCES trajets(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expediteur_id INTEGER NOT NULL,
        destinataire_id INTEGER NOT NULL,
        contenu TEXT NOT NULL,
        date_envoi TEXT NOT NULL,
        lu INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (expediteur_id) REFERENCES users(id),
        FOREIGN KEY (destinataire_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE planning (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        trajet_id INTEGER NOT NULL,
        date_planifiee TEXT NOT NULL,
        statut TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (trajet_id) REFERENCES trajets(id)
      )
    ''');
  }
}