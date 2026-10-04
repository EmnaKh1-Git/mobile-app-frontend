import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  static UserService get instance => _instance;

  UserService._internal() {
    // Default demo user for easy testing
    _currentUser = UserModel(
      id: 'usr_101',
      nom: 'Dupont',
      prenom: 'Alexandre',
      email: 'alexandre.dupont@etudiant.univ.fr',
      telephone: '+33 6 12 34 56 78',
      role: UserRole.passager,
      universite: 'Université Paris-Saclay',
      note: 4.8,
      nombreTrajets: 24,
      modeleVehicule: 'Peugeot 208 Bleu',
      immatriculation: 'AB-123-CD',
      dateInscription: DateTime.now().subtract(const Duration(days: 120)),
    );
  }

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Simulation d'une connexion utilisateur
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 900));

    // Validation simple pour la démo
    if (email.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Veuillez remplir tous les champs.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (!email.contains('@')) {
      _errorMessage = 'Adresse email invalide.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Extraction du prénom/nom si c'est un nouvel email ou conservation du mock
    final parts = email.split('@').first.split('.');
    final prenom = parts.isNotEmpty
        ? parts[0][0].toUpperCase() + parts[0].substring(1)
        : 'Étudiant';
    final nom = parts.length > 1
        ? parts[1][0].toUpperCase() + parts[1].substring(1)
        : 'Campus';

    _currentUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom,
      prenom: prenom,
      email: email.trim(),
      telephone: '+33 6 98 76 54 32',
      role: UserRole.passager,
      universite: 'Université Campus',
      note: 5.0,
      nombreTrajets: 1,
      dateInscription: DateTime.now(),
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Simulation de l'inscription d'un utilisateur
  Future<bool> register({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required UserRole role,
    required String password,
    String? universite,
    String? immatriculation,
    String? modeleVehicule,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));

    _currentUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: email.trim(),
      telephone: telephone.trim(),
      role: role,
      universite: (universite != null && universite.trim().isNotEmpty)
          ? universite.trim()
          : 'Université Campus',
      immatriculation: immatriculation?.trim(),
      modeleVehicule: modeleVehicule?.trim(),
      note: 5.0,
      nombreTrajets: 0,
      dateInscription: DateTime.now(),
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Basculer entre le rôle Passager et Conducteur
  Future<void> toggleRole() async {
    if (_currentUser == null) return;

    final newRole = _currentUser!.role == UserRole.passager
        ? UserRole.conducteur
        : UserRole.passager;

    _currentUser = _currentUser!.copyWith(role: newRole);
    notifyListeners();
  }

  /// Mettre à jour explicitement le rôle
  Future<void> updateRole(UserRole newRole) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(role: newRole);
    notifyListeners();
  }

  /// Mettre à jour les informations du profil
  Future<void> updateProfile({
    String? nom,
    String? prenom,
    String? telephone,
    String? universite,
    String? immatriculation,
    String? modeleVehicule,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      nom: nom,
      prenom: prenom,
      telephone: telephone,
      universite: universite,
      immatriculation: immatriculation,
      modeleVehicule: modeleVehicule,
    );
    notifyListeners();
  }

  /// Déconnexion de l'utilisateur
  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }
}
