import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'database_service.dart';
import 'email_service.dart';
import 'biometric_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    final normalizedEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // 1. Vérification locale prioritaire (SQLite) : source de vérité
    final localUser = await _db.getUserByEmail(normalizedEmail);
    UserModel? user;

    if (localUser != null) {
      final isLocalValid =
          await _db.verifyCredentials(normalizedEmail, cleanPassword);
      if (isLocalValid) {
        user = localUser;
        // Tenter d'authentifier Supabase en arrière-plan avec le mot de passe valide
        try {
          await SupabaseService.instance.client.auth
              .signInWithPassword(email: normalizedEmail, password: cleanPassword);
        } catch (_) {}
      } else {
        // Le mot de passe entré ne correspond PAS au mot de passe actif du compte
        // L'ancien mot de passe révoqué ou un mot de passe erroné est STRICTEMENT rejeté
        _errorMessage = 'Mot de passe incorrect. Veuillez vérifier vos identifiants.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } else {
      // 2. Si le compte n'existe pas encore en local (premier accès sur ce terminal)
      try {
        final response = await SupabaseService.instance.client.auth
            .signInWithPassword(email: normalizedEmail, password: cleanPassword);
        final remoteUser = response.user;
        if (remoteUser != null) {
          final profile = await SupabaseService.instance.client
              .from('profiles')
              .select()
              .eq('id', remoteUser.id)
              .maybeSingle();
          if (profile != null) {
            user = UserModel.fromMap({
              ...Map<String, dynamic>.from(profile),
              'id': profile['local_id'] ?? remoteUser.id,
            });
            await _db.insertUser(user, cleanPassword);
          }
        }
      } catch (error) {
        debugPrint('[UserService] Connexion distante impossible : $error');
      }
    }

    if (user == null) {
      _errorMessage = 'Aucun compte associé à l\'adresse "$email".';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.isBanni) {
      _errorMessage =
          '🚫 Ce compte a été suspendu par l\'administration.\n${user.raisonBlocage ?? "Veuillez contacter le support."}';
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

  Future<bool> loginWithBiometrics({
    String? email,
    bool skipHardwareCheck = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final creds = await BiometricService.instance.getEnrolledCredentials();
    final targetEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim().toLowerCase()
        : creds?['email'] as String?;

    if (targetEmail == null || targetEmail.isEmpty) {
      _errorMessage = 'Aucune empreinte ou visage configuré sur cet appareil.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (!skipHardwareCheck) {
      final authenticated = await BiometricService.instance.authenticateSystem(
        reason:
            'Authentifiez-vous par empreinte ou visage pour accéder à UniDrive',
      );
      if (!authenticated) {
        _errorMessage = 'Authentification biométrique annulée ou non reconnue.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    final user = await _db.getUserByEmail(targetEmail);
    if (user == null) {
      _errorMessage = 'Le compte associé à cette biométrie est introuvable.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.isBanni) {
      _errorMessage =
          '🚫 Ce compte a été suspendu par l\'administration.\n${user.raisonBlocage ?? "Veuillez contacter le support."}';
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

  Future<bool> enrollBiometrics({
    required String email,
    required String password,
    required bool faceEnrolled,
    required bool fingerprintEnrolled,
    String? faceDataPath,
    String? fingerprintDataPath,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = await _db.getUserByEmail(normalizedEmail);
    if (user == null) return false;

    await BiometricService.instance.saveEnrolledCredentials(
      email: normalizedEmail,
      password: password,
      faceEnrolled: faceEnrolled,
      fingerprintEnrolled: fingerprintEnrolled,
      faceDataPath: faceDataPath,
    );

    await _db.updateBiometrics(
      user.id,
      enabled: true,
      face: faceEnrolled,
      fingerprint: fingerprintEnrolled,
      faceDataPath: faceDataPath,
    );

    if (_currentUser != null && _currentUser!.id == user.id) {
      _currentUser = _currentUser!.copyWith(
        biometrieActive: true,
        faceEnrolled: faceEnrolled,
        fingerprintEnrolled: fingerprintEnrolled,
        faceDataPath: faceDataPath ?? _currentUser!.faceDataPath,
      );
    }

    notifyListeners();
    return true;
  }

  Future<void> disableBiometrics(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = await _db.getUserByEmail(normalizedEmail);
    await BiometricService.instance.clearBiometrics();

    if (user != null) {
      await _db.updateBiometrics(
        user.id,
        enabled: false,
        face: false,
        fingerprint: false,
      );
    }

    if (_currentUser != null &&
        _currentUser!.email.toLowerCase() == normalizedEmail) {
      _currentUser = _currentUser!.copyWith(
        biometrieActive: false,
        faceEnrolled: false,
        fingerprintEnrolled: false,
      );
    }

    notifyListeners();
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
    bool biometrieActive = false,
    bool faceEnrolled = false,
    bool fingerprintEnrolled = false,
    String? faceDataPath,
    String? fingerprintDataPath,
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
      biometrieActive: biometrieActive || faceEnrolled || fingerprintEnrolled,
      faceEnrolled: faceEnrolled,
      fingerprintEnrolled: fingerprintEnrolled,
      faceDataPath: faceDataPath,
      fingerprintDataPath: fingerprintDataPath,
    );

    await _db.insertUser(newUser, password);

    if (biometrieActive || faceEnrolled || fingerprintEnrolled) {
      try {
        await BiometricService.instance.saveEnrolledCredentials(
          email: normalizedEmail,
          password: password,
          faceEnrolled: faceEnrolled,
          fingerprintEnrolled: fingerprintEnrolled,
          faceDataPath: faceDataPath,
          fingerprintDataPath: fingerprintDataPath,
        );
      } catch (e) {
        debugPrint('[UserService] Enregistrement biométrique local ignoré : $e');
      }
    }
    try {
      final response = await SupabaseService.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
      );
      final remoteUser = response.user;
      if (remoteUser != null) {
        await SupabaseService.instance.client
            .from('profiles')
            .upsert(_remoteProfile(newUser, remoteUser.id), onConflict: 'id');
      }
    } catch (error) {
      debugPrint('[UserService] Inscription Supabase impossible : $error');
    }
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
    final cleanPassword = newPassword.trim();

    // 1. S'assurer que le profil existe en base locale
    var user = await _db.getUserByEmail(normalizedEmail);
    if (user == null) {
      try {
        final profile = await SupabaseService.instance.client
            .from('profiles')
            .select()
            .eq('email', normalizedEmail)
            .maybeSingle();
        if (profile != null) {
          user = UserModel.fromMap({
            ...Map<String, dynamic>.from(profile),
            'id': profile['local_id'] ?? profile['id'],
          });
          await _db.insertUser(user, cleanPassword);
        }
      } catch (e) {
        debugPrint('[UserService] Recherche profil distant pour reset: $e');
      }
    }

    // 2. Mettre à jour le mot de passe dans SQLite
    bool success = await _db.updatePassword(normalizedEmail, cleanPassword);
    if (!success && user != null) {
      await _db.insertUser(user, cleanPassword);
      success = true;
    }

    if (success) {
      _resetCodes.remove(normalizedEmail);
      _currentUser = await _db.getUserByEmail(normalizedEmail);

      // 3. Mettre à jour les identifiants biométriques enregistrés pour ce compte
      try {
        await BiometricService.instance.updateSavedPassword(
          normalizedEmail,
          cleanPassword,
        );
      } catch (e) {
        debugPrint('[UserService] Erreur mise à jour mot de passe bio: $e');
      }

      // 4. Mettre à jour Supabase Auth si une session est disponible
      try {
        if (SupabaseService.instance.currentUser?.email == normalizedEmail) {
          await SupabaseService.instance.client.auth.updateUser(
            UserAttributes(password: cleanPassword),
          );
        }
      } catch (e) {
        debugPrint('[UserService] Note: Supabase updateUser: $e');
      }
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
    await _syncCurrentProfile();
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
    await _syncCurrentProfile();
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
    await _syncCurrentProfile();
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
    try {
      await SupabaseService.instance.signOut();
    } catch (error) {
      debugPrint('[UserService] Déconnexion Supabase impossible : $error');
    }
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  Map<String, dynamic> _remoteProfile(UserModel user, String authId) => {
    'id': authId,
    'local_id': user.id,
    'nom': user.nom,
    'prenom': user.prenom,
    'email': user.email,
    'telephone': user.telephone,
    'indicatifTel': user.indicatifTel,
    'role': user.role.name,
    'avatarUrl': user.avatarUrl,
    'gouvernorat': user.gouvernorat,
    'universite': user.universite,
    'note': user.note,
    'nombreTrajets': user.nombreTrajets,
    'marqueVehicule': user.marqueVehicule,
    'modeleVehicule': user.modeleVehicule,
    'couleurVehicule': user.couleurVehicule,
    'immatriculation': user.immatriculation,
    'placesDisponibles': user.placesDisponibles,
    'dateInscription': user.dateInscription?.toIso8601String(),
    'isBanni': user.isBanni,
    'isBloque': user.isBloque,
    'raisonBlocage': user.raisonBlocage,
  };

  Future<void> _syncCurrentProfile() async {
    final user = _currentUser;
    final authUser = SupabaseService.instance.currentUser;
    if (user == null || authUser == null) return;
    try {
      await SupabaseService.instance.client
          .from('profiles')
          .upsert(_remoteProfile(user, authUser.id), onConflict: 'id');
    } catch (error) {
      debugPrint('[UserService] Profil Supabase non synchronisé : $error');
    }
  }

  /// Tous les utilisateurs : profils Supabase (recopiés localement) et
  /// comptes créés sur cet appareil
  Future<List<UserModel>> getAllUsersForAdmin() async {
    try {
      final rows =
          await SupabaseService.instance.client.from('profiles').select();
      await _db.synchroniserProfils([
        for (final row in rows)
          UserModel.fromMap({
            ...Map<String, dynamic>.from(row),
            'id': row['local_id'] ?? row['id'],
          }),
      ]);
    } catch (error) {
      debugPrint('[UserService] Profils Supabase non lus : $error');
    }
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
