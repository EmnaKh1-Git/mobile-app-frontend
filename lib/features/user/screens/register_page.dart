import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../models/user_model.dart';
import '../models/tunisia_data.dart';
import '../services/user_service.dart';
import '../../../screens/accueil_page.dart';
import 'widgets/captcha_widget.dart';
import 'widgets/user_avatar_view.dart';
import 'widgets/google_sign_in_modal.dart';
import 'widgets/auth_map_background.dart';
import 'privacy_policy_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedAvatarId = 'avatar_etudiant';

  String _selectedMarque = 'Peugeot';
  String _selectedModele = '208';
  String _selectedCouleur = 'Noir';
  final _immatriculationController = TextEditingController(
    text: '220 TUN 1234',
  );
  int _placesDisponibles = 3;

  String _selectedCountryCode = '+216';
  String _selectedGouvernorat = 'Ariana';
  String _selectedUniversite = 'ESPRIT (Pôle Ghazela)';

  UserRole _selectedRole = UserRole.passager;

  final _captchaController = TextEditingController();
  final _captchaKey = GlobalKey<CaptchaWidgetState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  final _userService = UserService.instance;

  void _goToStep(int step) {
    if (step < 0 || step > 2) return;
    setState(() {
      _currentStep = step;
      _errorMessage = null;
    });
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_prenomController.text.trim().isEmpty ||
          _nomController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@') ||
          _phoneController.text.trim().length < 8) {
        setState(
          () => _errorMessage =
              'Veuillez compléter vos informations personnelles obligatoires.',
        );
        return false;
      }
    } else if (_currentStep == 2) {
      if (!_formKey.currentState!.validate()) return false;
    }
    return true;
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      _goToStep(_currentStep + 1);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _immatriculationController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _onGouvernoratChanged(String? newGov) {
    if (newGov == null) return;
    setState(() {
      _selectedGouvernorat = newGov;
      final univs = kTunisianGovernoratesAndUniversities[newGov] ?? [];
      _selectedUniversite = univs.isNotEmpty
          ? univs.first
          : 'Autre établissement';
    });
  }

  void _onMarqueChanged(String? newMarque) {
    if (newMarque == null) return;
    setState(() {
      _selectedMarque = newMarque;
      final modeles = kCarBrandsAndModels[newMarque] ?? [];
      _selectedModele = modeles.isNotEmpty ? modeles.first : 'Autre modèle';
    });
  }

  Future<void> _pickImageFromGalleryOrComputer() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedAvatarId = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo sélectionnée avec succès depuis votre appareil !',
              ),
              backgroundColor: AppColors.primaire,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _showManualPathOrFallbackDialog();
      }
    }
  }

  void _showManualPathOrFallbackDialog() {
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_open, color: AppColors.primaire),
            SizedBox(width: 8),
            Text('Parcourir vos photos', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez le chemin ou le lien de votre photo de profil :',
              style: TextStyle(fontSize: 13, color: AppColors.texte2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'Chemin local ou URL de la photo',
                hintText: 'C:\\Users\\user\\Pictures\\avatar.jpg',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = pathCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() => _selectedAvatarId = text);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaire,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisir votre photo / avatar de profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaire,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Parcourez les photos de votre appareil ou choisissez un avatar étudiant :',
                style: TextStyle(fontSize: 12, color: AppColors.texte2),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pickImageFromGalleryOrComputer();
                },
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 20),
                label: const Text(
                  '📁 Parcourir mes photos (Téléphone / PC)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaire,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ou choisir un avatar étudiant :',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: kAvatarPresets.map((item) {
                  final isSelected = _selectedAvatarId == item.id;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedAvatarId = item.id);
                      Navigator.of(ctx).pop();
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaire
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: item.color,
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez accepter la charte et les conditions d\'utilisation.',
          ),
          backgroundColor: AppColors.alerte,
        ),
      );
      return;
    }

    if (_captchaKey.currentState != null &&
        !_captchaKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Code anti-robot invalide. Veuillez vérifier le code.';
      });
      _captchaKey.currentState?.refresh();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_selectedAvatarId.contains('/') || _selectedAvatarId.contains('\\')) {
      final uploadedUrl = await SupabaseStorageService.instance.uploadImage(
        _selectedAvatarId,
      );
      if (uploadedUrl != null) {
        _selectedAvatarId = uploadedUrl;
      }
    }

    final success = await _userService.register(
      nom: _nomController.text,
      prenom: _prenomController.text,
      email: _emailController.text,
      telephone: _phoneController.text,
      indicatifTel: _selectedCountryCode,
      role: _selectedRole,
      password: _passwordController.text,
      gouvernorat: _selectedGouvernorat,
      universite: _selectedUniversite,
      avatarUrl: _selectedAvatarId,
      marqueVehicule: _selectedRole.isConducteur ? _selectedMarque : null,
      modeleVehicule: _selectedRole.isConducteur ? _selectedModele : null,
      couleurVehicule: _selectedRole.isConducteur ? _selectedCouleur : null,
      immatriculation: _selectedRole.isConducteur
          ? _immatriculationController.text
          : null,
      placesDisponibles: _selectedRole.isConducteur ? _placesDisponibles : 0,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé avec succès ! Bienvenue sur UniDrive.'),
          backgroundColor: AppColors.primaire,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AccueilPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage =
            _userService.errorMessage ?? 'Erreur lors de l\'inscription.';
      });
      _captchaKey.currentState?.refresh();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final account = await GoogleSignInModal.show(context);
    if (account == null) return;

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final success = await _userService.loginWithGoogleAccount(
      email: account.email,
      prenom: account.prenom,
      nom: account.nom,
      avatarId: account.avatarId,
      fullUser: account.fullUser,
    );

    if (!mounted) return;

    setState(() {
      _isGoogleLoading = false;
    });

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AccueilPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = 'Échec de la connexion avec Google.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final universitesDisponibles =
        kTunisianGovernoratesAndUniversities[_selectedGouvernorat] ?? [];
    final modelesDisponibles =
        kCarBrandsAndModels[_selectedMarque] ?? ['Autre modèle'];

    final previewUser = UserModel(
      id: 'preview',
      nom: _nomController.text.isNotEmpty ? _nomController.text : 'Nom',
      prenom: _prenomController.text.isNotEmpty
          ? _prenomController.text
          : 'Prénom',
      email: '',
      telephone: '',
      role: _selectedRole,
      avatarUrl: _selectedAvatarId,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barre supérieure avec bouton retour circulaire (Screen 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bordure),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () {
                            if (_currentStep > 0) {
                              _goToStep(_currentStep - 1);
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.primaire,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const BotanicalLeaf(size: 40),
                  ],
                ),

                const SizedBox(height: 16),

                // Titre "Register" + Sous-titre (Screen 3)
                const Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaire,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your new account',
                  style: TextStyle(fontSize: 13.5, color: AppColors.texte2),
                ),

                const SizedBox(height: 20),

                // Barres de progression d'étapes (3 barres pilules)
                Row(
                  children: List.generate(3, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaire
                              : AppColors.champFond,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 10),

                Text(
                  [
                    'Étape 1 sur 3 : Coordonnées',
                    'Étape 2 sur 3 : Localisation & Véhicule',
                    'Étape 3 sur 3 : Sécurité & Finalisation',
                  ][_currentStep],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primaire,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),

                const SizedBox(height: 18),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF8B4B4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFC81E1E),
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFF9B1C1C),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ==========================================
                // ÉTAPE 0 : Informations personnelles & Rôle
                // ==========================================
                if (_currentStep == 0) ...[
                  Center(
                    child: Column(
                      children: [
                        UserAvatarView(
                          user: previewUser,
                          radius: 38,
                          showCameraBadge: true,
                          onTap: _showAvatarPickerModal,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _showAvatarPickerModal,
                          child: const Text(
                            'Changer la photo de profil',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaire,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Vous êtes :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.texte,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          title: 'Passager',
                          icon: Icons.person_rounded,
                          isSelected: _selectedRole == UserRole.passager,
                          onTap: () =>
                              setState(() => _selectedRole = UserRole.passager),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          title: 'Conducteur',
                          icon: Icons.directions_car_rounded,
                          isSelected: _selectedRole == UserRole.conducteur,
                          onTap: () => setState(
                            () => _selectedRole = UserRole.conducteur,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Prénom et Nom
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prenomController,
                          decoration: _buildPillDecoration(
                            'Prénom',
                            Icons.person_outline_rounded,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _nomController,
                          decoration: _buildPillDecoration(
                            'Nom',
                            Icons.badge_outlined,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Email avec coche de validation (Screen 3)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    decoration: _buildPillDecoration(
                      'user@mail.com',
                      Icons.mail_outline_rounded,
                      suffix:
                          _emailController.text.contains('@') &&
                              _emailController.text.contains('.')
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accent,
                              size: 20,
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir votre email';
                      }
                      if (!value.contains('@')) {
                        return 'Format d\'email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Téléphone avec indicatif
                  Row(
                    children: [
                      Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.champFond,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: AppColors.texte2,
                            ),
                            items: kCountryCodes.map((country) {
                              return DropdownMenuItem<String>(
                                value: country.code,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      country.flag,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      country.code,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.texte,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCountryCode = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _buildPillDecoration(
                            'Numéro (ex: 20 123 456)',
                            Icons.phone_android_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Téléphone requis';
                            }
                            if (value.trim().length < 8) {
                              return 'Numéro trop court';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                // ==========================================
                // ÉTAPE 1 : Localisation & Véhicule
                // ==========================================
                if (_currentStep == 1) ...[
                  const Text(
                    'Gouvernorat de départ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.texte,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.champFond,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value:
                            kTunisianGovernoratesAndUniversities.containsKey(
                              _selectedGouvernorat,
                            )
                            ? _selectedGouvernorat
                            : 'Tunis',
                        items: kTunisianGovernoratesAndUniversities.keys.map((
                          gov,
                        ) {
                          return DropdownMenuItem<String>(
                            value: gov,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: AppColors.primaire,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  gov,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onGouvernoratChanged,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Université / Établissement',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.texte,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.champFond,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value:
                            universitesDisponibles.contains(_selectedUniversite)
                            ? _selectedUniversite
                            : (universitesDisponibles.isNotEmpty
                                  ? universitesDisponibles.first
                                  : null),
                        items: universitesDisponibles.map((univ) {
                          return DropdownMenuItem<String>(
                            value: univ,
                            child: Text(
                              univ,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedUniversite = val);
                          }
                        },
                      ),
                    ),
                  ),

                  if (_selectedRole == UserRole.conducteur) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaireDoux.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaire.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.directions_car_filled_rounded,
                                color: AppColors.primaire,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Détails de votre véhicule',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaire,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Marque',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.bordure,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value:
                                              kCarBrandsAndModels.containsKey(
                                                _selectedMarque,
                                              )
                                              ? _selectedMarque
                                              : 'Peugeot',
                                          items: kCarBrandsAndModels.keys.map((
                                            b,
                                          ) {
                                            return DropdownMenuItem(
                                              value: b,
                                              child: Text(
                                                b,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _onMarqueChanged,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Modèle',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.bordure,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value:
                                              modelesDisponibles.contains(
                                                _selectedModele,
                                              )
                                              ? _selectedModele
                                              : (modelesDisponibles.isNotEmpty
                                                    ? modelesDisponibles.first
                                                    : null),
                                          items: modelesDisponibles.map((m) {
                                            return DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                m,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => _selectedModele = val,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Couleur',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.bordure,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value:
                                              kCarColors.contains(
                                                _selectedCouleur,
                                              )
                                              ? _selectedCouleur
                                              : 'Noir',
                                          items: kCarColors.map((c) {
                                            return DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => _selectedCouleur = val,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Immatriculation',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _immatriculationController,
                                      style: const TextStyle(fontSize: 12.5),
                                      decoration: InputDecoration(
                                        hintText: '220 TUN 1234',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.bordure,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.bordure,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Places disponibles :',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [1, 2, 3, 4].map((count) {
                                  final isSel = _placesDisponibles == count;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _placesDisponibles = count,
                                      ),
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? AppColors.primaire
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSel
                                                ? AppColors.primaire
                                                : AppColors.bordure,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : AppColors.texte,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                // ==========================================
                // ÉTAPE 2 : Mot de passe & CGU
                // ==========================================
                if (_currentStep == 2) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildPillDecoration(
                      '••••••••',
                      Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.texte2,
                          size: 19,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez choisir un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Minimum 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _buildPillDecoration(
                      '•••••••• (Confirmer)',
                      Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.texte2,
                          size: 19,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  CaptchaWidget(
                    key: _captchaKey,
                    controller: _captchaController,
                  ),
                  const SizedBox(height: 14),

                  InkWell(
                    onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _acceptTerms
                                ? AppColors.primaire
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _acceptTerms
                                  ? AppColors.primaire
                                  : AppColors.texte2.withValues(alpha: 0.5),
                              width: 1.6,
                            ),
                          ),
                          child: _acceptTerms
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "J'accepte la charte étudiante et la politique de confidentialité",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.texte2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      ),
                      child: const Text(
                        'Lire la politique de confidentialité (FR / 中文)',
                        style: TextStyle(
                          color: AppColors.primaire,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Boutons d'action (Précédent / Continuer / Créer)
                if (_currentStep < 2) ...[
                  Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => _goToStep(_currentStep - 1),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.bordure,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text(
                                'Précédent',
                                style: TextStyle(
                                  color: AppColors.texte,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaire,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: AppColors.primaire.withValues(
                                alpha: 0.35,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              'Continuer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaire,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: AppColors.primaire.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Rangée sociale "Or continue with" (Screen 3)
                SocialLoginRow(
                  isLoading: _isGoogleLoading,
                  onGoogleTap: _handleGoogleSignIn,
                ),

                const SizedBox(height: 22),

                // Lien bas de page "Already have an account? Sign up" (Screen 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.texte2, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AppColors.primaire,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildPillDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.texte2.withValues(alpha: 0.65),
        fontSize: 13.5,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, color: AppColors.texte2, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.champFond,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primaire, width: 1.5),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.champFond : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaire : AppColors.bordure,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaire.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaire : AppColors.texte2,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaire : AppColors.texte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
