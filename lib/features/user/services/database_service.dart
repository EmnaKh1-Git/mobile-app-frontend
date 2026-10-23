import '../../../core/services/database_service.dart' as core;
import '../models/user_model.dart';

import 'package:sqflite/sqflite.dart';

typedef DatabaseService = DatabaseServicee;

class DatabaseServicee {
  static final DatabaseServicee instance = DatabaseServicee._();
  DatabaseServicee._();

  bool _adminEnsured = false;

  Future<Database> get _database async => _prepareDatabase();

  Future<Database> _prepareDatabase() async {
    final db = await core.DatabaseService.instance.database;
    if (!_adminEnsured) {
      final admin = UserModel(
        id: 'usr_admin_principal',
        nom: 'Responsable',
        prenom: 'Admin ESPRIT',
        email: 'admin@esprit.tn',
        telephone: '71123456',
        role: UserRole.administrateur,
        avatarUrl: 'avatar_conducteur',
        gouvernorat: 'Tunis',
        universite: 'ESPRIT (Direction Générale)',
        note: 5,
        dateInscription: DateTime.now(),
      );
      final existing = await db.query(
        'app_users',
        where: 'email = ?',
        whereArgs: [admin.email],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('app_users', _userMap(admin, 'Admin123!'));
      }
      _adminEnsured = true;
    }
    return db;
  }

  Map<String, dynamic> _userMap(UserModel user, String password) {
    final map = {...user.toMap(), 'password': password};
    map['isBanni'] = user.isBanni ? 1 : 0;
    map['isBloque'] = user.isBloque ? 1 : 0;
    return map;
  }

  UserModel _userFromRow(Map<String, Object?> row) =>
      UserModel.fromMap(Map<String, dynamic>.from(row));

  Future<bool> insertUser(UserModel user, String password) async {
    final db = await _database;
    await db.insert(
      'app_users',
      _userMap(user, password),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await _database;
    final rows = await db.query(
      'app_users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : _userFromRow(rows.first);
  }

  Future<bool> verifyCredentials(String email, String password) async {
    final db = await _database;
    final rows = await db.query(
      'app_users',
      columns: ['password'],
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['password'] == password;
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    final db = await _database;
    return await db.update(
          'app_users',
          {'password': newPassword},
          where: 'LOWER(email) = ?',
          whereArgs: [email.trim().toLowerCase()],
        ) >
        0;
  }

  Future<bool> updateUser(UserModel user) async {
    final db = await _database;
    final values = user.toMap()
      ..['isBanni'] = user.isBanni ? 1 : 0
      ..['isBloque'] = user.isBloque ? 1 : 0;
    return await db.update(
          'app_users',
          values,
          where: 'id = ?',
          whereArgs: [user.id],
        ) >
        0;
  }

  Future<bool> banUser(String email, {String? reason}) async {
    final db = await _database;
    return await db.update(
          'app_users',
          {
            'isBanni': 1,
            'raisonBlocage': reason ?? 'Compte suspendu par l’administration.',
          },
          where: 'LOWER(email) = ?',
          whereArgs: [email.trim().toLowerCase()],
        ) >
        0;
  }

  Future<bool> unbanUser(String email) async {
    final db = await _database;
    return await db.update(
          'app_users',
          {'isBanni': 0, 'isBloque': 0, 'raisonBlocage': null},
          where: 'LOWER(email) = ?',
          whereArgs: [email.trim().toLowerCase()],
        ) >
        0;
  }

  Future<bool> deleteUser(String userId) async {
    final db = await _database;
    return await db.delete('app_users', where: 'id = ?', whereArgs: [userId]) >
        0;
  }

  Future<bool> deleteUserByEmail(String email) async {
    final db = await _database;
    return await db.delete(
          'app_users',
          where: 'LOWER(email) = ?',
          whereArgs: [email.trim().toLowerCase()],
        ) >
        0;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await _database;
    final rows = await db.query('app_users', orderBy: 'nom ASC, prenom ASC');
    return rows.map(_userFromRow).toList();
  }
}
