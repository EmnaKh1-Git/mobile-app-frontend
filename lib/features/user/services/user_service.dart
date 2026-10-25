import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'database_service.dart';
import 'email_service.dart';
import '../../../core/services/cloudinary_service.dart';

class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  static UserService get instance => _instance;

  UserService._internal();

  final DatabaseServicee _db = DatabaseServicee.instance;
  final EmailService _emailService = EmailService.instance;
  final CloudinaryService _cloudinary = CloudinaryService.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, String> _resetCodes = {};

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    final user = await _db.getUserByEmail(normalizedEmail);

    if (user != null && user.isBanni) {
      _errorMessage =
          '🚫 Ce compte a été suspendu par l\'administration.\n${user.raisonBlocage ?? "Veuillez contacter le support."}';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final isValid = await _db.verifyCredentials(normalizedEmail, password);

    if (!isValid) {
      _errorMessage = user == null
          ? 'Aucun compte associé à l\'adresse "$email".'
          : 'Mot de passe incorrect. Veuillez vérifier vos identifiants.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogleAccount({
    required String email,
    required String prenom,
    required String nom,
    String? avatarId,
    UserModel? fullUser,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));

    final normalizedEmail = email.trim().toLowerCase();
    final existingUser = await _db.getUserByEmail(normalizedEmail);

    if (existingUser != null && existingUser.isBanni) {
      _errorMessage =
          '🚫 Ce compte Google a été suspendu par l\'administration.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (fullUser != null) {
      _currentUser = fullUser;
      await _db.updateUser(_currentUser!);
    } else if (existingUser != null) {
      _currentUser = existingUser;
    } else {
      final newUser = UserModel(
        id: 'usr_google_${DateTime.now().millisecondsSinceEpoch}',
        nom: nom.trim().isNotEmpty ? nom.trim() : 'Étudiant',
        prenom: prenom.trim().isNotEmpty ? prenom.trim() : 'Google',
        email: normalizedEmail,
        telephone: '20123456',
        indicatifTel: '+216',
        role: UserRole.passager,
        avatarUrl: avatarId ?? 'avatar_etudiant',
        gouvernorat: 'Tunis',
        universite: 'ESPRIT (Pôle Ghazela)',
        note: 5.0,
        nombreTrajets: 0,
        dateInscription: DateTime.now(),
      );
      await _db.insertUser(newUser, 'GoogleAuthSecure123!');
      _currentUser = newUser;
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    String indicatifTel = '+216',
    required UserRole role,
    required String password,
    String gouvernorat = 'Tunis',
    String universite = 'ESPRIT (Pôle Ghazela)',
    String? marqueVehicule,
    String? modeleVehicule,
    String? couleurVehicule,
    String? immatriculation,
    int placesDisponibles = 3,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    final existing = await _db.getUserByEmail(normalizedEmail);

    if (existing != null) {
      _errorMessage =
          'Un compte existe déjà avec cet email. Veuillez vous connecter.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    var storedAvatarUrl = avatarUrl;
    if (storedAvatarUrl != null && !storedAvatarUrl.startsWith('avatar_')) {
      try {
        storedAvatarUrl = await _cloudinary.uploadIfLocalPath(storedAvatarUrl);
      } on CloudinaryUploadException {
        // The local path is retained as an offline fallback.
      }
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: normalizedEmail,
      telephone: telephone.trim(),
      indicatifTel: indicatifTel,
      role: role,
      gouvernorat: gouvernorat,
      universite: universite,
      avatarUrl:
          storedAvatarUrl ??
          (role.isConducteur ? 'avatar_conducteur' : 'avatar_etudiant'),
      marqueVehicule: marqueVehicule?.trim(),
      modeleVehicule: modeleVehicule?.trim(),
      couleurVehicule: couleurVehicule?.trim(),
      immatriculation: immatriculation?.trim(),
      placesDisponibles: placesDisponibles,
      note: 5.0,
      nombreTrajets: 0,
      dateInscription: DateTime.now(),
    );

    await _db.insertUser(newUser, password);
    _currentUser = newUser;

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> sendPasswordResetCode(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      _errorMessage = 'Veuillez saisir une adresse email valide.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    var user = await _db.getUserByEmail(normalizedEmail);

    if (user == null) {
      final prefix = normalizedEmail.split('@').first;
      final parts = prefix.split(RegExp(r'[._-]'));
      final prenom = parts.isNotEmpty && parts[0].isNotEmpty
          ? parts[0][0].toUpperCase() + parts[0].substring(1)
          : 'Étudiant';
      final nom = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1][0].toUpperCase() + parts[1].substring(1)
          : 'Campus';

      user = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        nom: nom,
        prenom: prenom,
        email: normalizedEmail,
        telephone: '20123456',
        indicatifTel: '+216',
        role: UserRole.passager,
        avatarUrl: 'avatar_etudiant',
        gouvernorat: 'Tunis',
        universite: 'ESPRIT (Charguia 2)',
        note: 5.0,
        nombreTrajets: 0,
        dateInscription: DateTime.now(),
      );

      await _db.insertUser(user, 'Pass123!');
    }

    final result = await _emailService.sendRecoveryEmail(
      recipientEmail: normalizedEmail,
      recipientName: '${user.prenom} ${user.nom}',
    );

    if (!result.success) {
      _errorMessage = result.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _resetCodes[normalizedEmail] = result.code;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  String? getLatestCode(String email) {
    return _resetCodes[email.trim().toLowerCase()];
  }

  bool verifyResetCode(String email, String code) {
    final normalizedEmail = email.trim().toLowerCase();
    final expectedCode = _resetCodes[normalizedEmail];
    return expectedCode != null && expectedCode == code.trim();
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    final success = await _db.updatePassword(normalizedEmail, newPassword);

    if (success) {
      _resetCodes.remove(normalizedEmail);
      _currentUser = await _db.getUserByEmail(normalizedEmail);
    } else {
      _errorMessage = 'Erreur lors de la mise à jour du mot de passe.';
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'Aucun utilisateur connecté.';
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final email = _currentUser!.email;
    final isOldPasswordValid = await _db.verifyCredentials(
      email,
      currentPassword,
    );
    if (!isOldPasswordValid) {
      _errorMessage = 'Le mot de passe actuel est incorrect.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final success = await _db.updatePassword(email, newPassword);
    if (!success) {
      _errorMessage = 'Erreur lors de la mise à jour du mot de passe.';
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> toggleRole() async {
    if (_currentUser == null || _currentUser!.isAdmin) return;

    final newRole = _currentUser!.role == UserRole.passager
        ? UserRole.conducteur
        : UserRole.passager;

    await updateRole(newRole);
  }

  Future<void> updateRole(UserRole newRole) async {
    if (_currentUser == null || _currentUser!.isAdmin) return;
    _currentUser = _currentUser!.copyWith(role: newRole);
    await _db.updateUser(_currentUser!);
    notifyListeners();
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (_currentUser == null) return;
    var storedAvatarUrl = avatarUrl;
    if (!avatarUrl.startsWith('avatar_')) {
      try {
        storedAvatarUrl = await _cloudinary.uploadIfLocalPath(avatarUrl);
      } on CloudinaryUploadException {
        // The local path is retained as an offline fallback.
      }
    }
    _currentUser = _currentUser!.copyWith(avatarUrl: storedAvatarUrl);
    await _db.updateUser(_currentUser!);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? nom,
    String? prenom,
    String? telephone,
    String? indicatifTel,
    String? gouvernorat,
    String? universite,
    String? marqueVehicule,
    String? modeleVehicule,
    String? couleurVehicule,
    String? immatriculation,
    int? placesDisponibles,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      nom: nom,
      prenom: prenom,
      telephone: telephone,
      indicatifTel: indicatifTel,
      gouvernorat: gouvernorat,
      universite: universite,
      marqueVehicule: marqueVehicule,
      modeleVehicule: modeleVehicule,
      couleurVehicule: couleurVehicule,
      immatriculation: immatriculation,
      placesDisponibles: placesDisponibles,
      avatarUrl: avatarUrl,
    );

    await _db.updateUser(_currentUser!);
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final success = await _db.deleteUser(_currentUser!.id);
    _currentUser = null;

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<UserModel>> getAllUsersForAdmin() async {
    return _db.getAllUsers();
  }

  Future<bool> banUser(String email, {String? reason}) async {
    final success = await _db.banUser(email, reason: reason);
    notifyListeners();
    return success;
  }

  Future<bool> unbanUser(String email) async {
    final success = await _db.unbanUser(email);
    notifyListeners();
    return success;
  }

  Future<bool> deleteUserByAdmin(String email) async {
    final success = await _db.deleteUserByEmail(email);
    notifyListeners();
    return success;
  }

  Future<bool> changeUserRoleByAdmin(String email, UserRole newRole) async {
    final user = await _db.getUserByEmail(email);
    if (user == null) return false;
    final updated = user.copyWith(role: newRole);
    final success = await _db.updateUser(updated);
    notifyListeners();
    return success;
  }
}
