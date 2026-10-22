import 'dart:convert';
import 'dart:io';
import '../models/user_model.dart';

typedef DatabaseService = DatabaseServicee;

class DatabaseRecord {
  final UserModel user;
  final String password;

  const DatabaseRecord({
    required this.user,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'user': user.toMap(),
      'password': password,
    };
  }

  factory DatabaseRecord.fromMap(Map<String, dynamic> map) {
    return DatabaseRecord(
      user: UserModel.fromMap(map['user'] as Map<String, dynamic>),
      password: map['password'] as String? ?? 'Pass123!',
    );
  }
}

class DatabaseServicee {
  static final DatabaseServicee _instance = DatabaseServicee._internal();
  static DatabaseServicee get instance => _instance;

  DatabaseServicee._internal() {
    _initLocalDatabase();
  }

  static const String databaseName = 'covoiturage_etudiant.db';
  static const String tableUsers = 'users';

  final Map<String, DatabaseRecord> _inMemoryDb = {};
  File? _dbFile;
  bool _isInitialized = false;

  File _resolveDatabaseFile() {
    if (Platform.isAndroid) {
      final candidates = [
        '/data/user/0/com.example.covoiturage_etudiant/files',
        '/data/data/com.example.covoiturage_etudiant/files',
        '/data/user/0/com.example.covoiturage_etudiant/app_flutter',
        Directory.systemTemp.path,
      ];
      for (final p in candidates) {
        try {
          final dir = Directory(p);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final test = File('${dir.path}/.test_rw');
          test.writeAsStringSync('ok');
          test.deleteSync();
          return File('${dir.path}/$databaseName');
        } catch (_) {}
      }
      return File('${Directory.systemTemp.path}/$databaseName');
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
      if (appData != null) {
        try {
          final dir = Directory('$appData/covoiturage_etudiant');
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return File('${dir.path}/$databaseName');
        } catch (_) {}
      }
      return File('${Directory.current.path}/$databaseName');
    }

    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final dir = Directory('$home/.covoiturage_etudiant');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/$databaseName');
  }

  Future<void> _initLocalDatabase() async {
    if (_isInitialized) return;

    try {
      _dbFile = _resolveDatabaseFile();

      if (await _dbFile!.exists()) {
        final content = await _dbFile!.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          for (final item in jsonList) {
            final record = DatabaseRecord.fromMap(item as Map<String, dynamic>);
            _inMemoryDb[record.user.email.toLowerCase()] = record;
          }
        }
      } else {
        final fallback = File('${Directory.systemTemp.path}/$databaseName');
        if (await fallback.exists()) {
          final content = await fallback.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(content);
            for (final item in jsonList) {
              final record = DatabaseRecord.fromMap(item as Map<String, dynamic>);
              _inMemoryDb[record.user.email.toLowerCase()] = record;
            }
          }
        }
      }
    } catch (_) {}

    _ensureAdminAccount();
    _isInitialized = true;
  }

  void _ensureAdminAccount() {
    const adminEmail = 'admin@esprit.tn';
    final existing = _inMemoryDb[adminEmail];
    if (existing == null || existing.user.role != UserRole.administrateur) {
      final adminUser = UserModel(
        id: 'usr_admin_principal',
        nom: 'Responsable',
        prenom: 'Admin ESPRIT',
        email: adminEmail,
        telephone: '71123456',
        indicatifTel: '+216',
        role: UserRole.administrateur,
        avatarUrl: 'avatar_conducteur',
        gouvernorat: 'Tunis',
        universite: 'ESPRIT (Direction Générale)',
        note: 5.0,
        nombreTrajets: 0,
        dateInscription: DateTime.now(),
      );
      _inMemoryDb[adminEmail] = DatabaseRecord(
        user: adminUser,
        password: existing?.password ?? 'Admin123!',
      );
      _persistToFile();
    }
  }

  Future<void> _persistToFile() async {
    try {
      _dbFile ??= _resolveDatabaseFile();
      final list = _inMemoryDb.values.map((r) => r.toMap()).toList();
      final jsonStr = jsonEncode(list);
      await _dbFile!.writeAsString(jsonStr, flush: true);

      try {
        final mirror = File('${Directory.systemTemp.path}/$databaseName');
        await mirror.writeAsString(jsonStr, flush: true);
      } catch (_) {}
    } catch (_) {}
  }

  Future<bool> insertUser(UserModel user, String password) async {
    await _initLocalDatabase();
    final normalized = user.email.trim().toLowerCase();
    _inMemoryDb[normalized] = DatabaseRecord(user: user, password: password);
    await _persistToFile();
    return true;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    return _inMemoryDb[normalized]?.user;
  }

  Future<bool> verifyCredentials(String email, String password) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    final record = _inMemoryDb[normalized];
    if (record == null) return false;
    return record.password == password;
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    final record = _inMemoryDb[normalized];
    if (record == null) return false;

    _inMemoryDb[normalized] = DatabaseRecord(user: record.user, password: newPassword);
    await _persistToFile();
    return true;
  }

  Future<bool> updateUser(UserModel user) async {
    await _initLocalDatabase();
    final normalized = user.email.trim().toLowerCase();
    final existing = _inMemoryDb[normalized];
    final password = existing?.password ?? 'Pass123!';

    _inMemoryDb[normalized] = DatabaseRecord(user: user, password: password);
    await _persistToFile();
    return true;
  }

  Future<bool> banUser(String email, {String? reason}) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    final existing = _inMemoryDb[normalized];
    if (existing == null) return false;

    final updated = existing.user.copyWith(
      isBanni: true,
      raisonBlocage: reason ?? 'Compte suspendu par l\'administrateur.',
    );
    _inMemoryDb[normalized] = DatabaseRecord(user: updated, password: existing.password);
    await _persistToFile();
    return true;
  }

  Future<bool> unbanUser(String email) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    final existing = _inMemoryDb[normalized];
    if (existing == null) return false;

    final updated = existing.user.copyWith(
      isBanni: false,
      isBloque: false,
      raisonBlocage: null,
    );
    _inMemoryDb[normalized] = DatabaseRecord(user: updated, password: existing.password);
    await _persistToFile();
    return true;
  }

  Future<bool> deleteUser(String userId) async {
    await _initLocalDatabase();
    _inMemoryDb.removeWhere((email, record) => record.user.id == userId);
    await _persistToFile();
    return true;
  }

  Future<bool> deleteUserByEmail(String email) async {
    await _initLocalDatabase();
    final normalized = email.trim().toLowerCase();
    _inMemoryDb.remove(normalized);
    await _persistToFile();
    return true;
  }

  Future<List<UserModel>> getAllUsers() async {
    await _initLocalDatabase();
    return _inMemoryDb.values.map((r) => r.user).toList();
  }
}
