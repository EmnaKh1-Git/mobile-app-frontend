import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/messagerie/data/messagerie_schema.dart';

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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // <-- ON AJOUTE LA FONCTION DE MISE À JOUR
    );
  }

  // Cette méthode s'exécute UNIQUEMENT lors d'une toute première installation
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
        lieuDepart TEXT NOT NULL,
        lieuDepartLat REAL,
        lieuDepartLng REAL,
        destination TEXT NOT NULL,
        destinationLat REAL,
        destinationLng REAL,
        date TEXT NOT NULL,
        heure TEXT NOT NULL,
        statut TEXT NOT NULL,
        rappelActif INTEGER NOT NULL,
        rappelDelai INTEGER NOT NULL,
        role TEXT NOT NULL,
        placesDisponibles INTEGER NOT NULL
      )
    ''');

    await _createAppUsersTable(db);
    await _createReclamationsTable(db);
    await MessagerieSchema.creerTables(db);
  }

  // Cette méthode s'exécute si l'application détecte une ancienne version (version 1)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // On ajoute les colonnes manquantes à la table existante sans perdre les données
      await db.execute('ALTER TABLE planning ADD COLUMN lieuDepartLat REAL;');
      await db.execute('ALTER TABLE planning ADD COLUMN lieuDepartLng REAL;');
      await db.execute('ALTER TABLE planning ADD COLUMN destinationLat REAL;');
      await db.execute('ALTER TABLE planning ADD COLUMN destinationLng REAL;');
    }
    if (oldVersion < 3) {
      await _createAppUsersTable(db);
      await _createReclamationsTable(db);
    }
    if (oldVersion < 4) {
      await MessagerieSchema.creerTables(db);
    }
  }

  Future<void> _createAppUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_users (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telephone TEXT NOT NULL,
        indicatifTel TEXT NOT NULL,
        role TEXT NOT NULL,
        avatarUrl TEXT,
        gouvernorat TEXT NOT NULL,
        universite TEXT NOT NULL,
        note REAL NOT NULL,
        nombreTrajets INTEGER NOT NULL,
        marqueVehicule TEXT,
        modeleVehicule TEXT,
        couleurVehicule TEXT,
        immatriculation TEXT,
        placesDisponibles INTEGER NOT NULL,
        dateInscription TEXT,
        isBanni INTEGER NOT NULL DEFAULT 0,
        isBloque INTEGER NOT NULL DEFAULT 0,
        raisonBlocage TEXT,
        password TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createReclamationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reclamations (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        sujet TEXT NOT NULL,
        description TEXT NOT NULL,
        trajet TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        autreCategorie TEXT,
        imagePath TEXT,
        audioPath TEXT,
        aiConseil TEXT,
        responses TEXT NOT NULL
      )
    ''');
  }
}
