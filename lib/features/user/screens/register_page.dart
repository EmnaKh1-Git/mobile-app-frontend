import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../models/user_model.dart';
import '../models/tunisia_data.dart';
import '../services/user_service.dart';
import '../../../screens/accueil_page.dart';
import 'widgets/captcha_widget.dart';
import 'widgets/user_avatar_view.dart';

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
  final _immatriculationController = TextEditingController(text: '220 TUN 1234');
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
  String? _errorMessage;

  final _userService = UserService.instance;

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
      _selectedUniversite = univs.isNotEmpty ? univs.first : 'Autre établissement';
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
              content: Text('Photo sélectionnée avec succès depuis votre appareil !'),
              backgroundColor: Color(0xFF10B981),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaire, foregroundColor: Colors.white),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Parcourez les photos de votre ordinateur ou choisissez un avatar étudiant :',
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
                  '📁 Parcourir mes photos (Ordinateur / Téléphone)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaire,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Ou choisir un avatar de profil :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
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
                          color: isSelected ? AppColors.primaire : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: item.color,
                            child: Icon(item.icon, color: Colors.white, size: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          content: Text('Veuillez accepter la charte et les conditions d\'utilisation.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_captchaKey.currentState != null && !_captchaKey.currentState!.validate()) {
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
      immatriculation: _selectedRole.isConducteur ? _immatriculationController.text : null,
      placesDisponibles: _selectedRole.isConducteur ? _placesDisponibles : 0,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé avec succès ! Bienvenue sur Covoiturage Étudiant.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AccueilPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = _userService.errorMessage ?? 'Erreur lors de l\'inscription.';
      });
      _captchaKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final universitesDisponibles = kTunisianGovernoratesAndUniversities[_selectedGouvernorat] ?? [];
    final modelesDisponibles = kCarBrandsAndModels[_selectedMarque] ?? ['Autre modèle'];

    final previewUser = UserModel(
      id: 'preview',
      nom: _nomController.text.isNotEmpty ? _nomController.text : 'Nom',
      prenom: _prenomController.text.isNotEmpty ? _prenomController.text : 'Prénom',
      email: '',
      telephone: '',
      role: _selectedRole,
      avatarUrl: _selectedAvatarId,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Créer un compte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Rejoignez la communauté étudiante',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Partagez vos trajets universitaires en toute sécurité',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.texte2,
                ),
              ),
              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppColors.bordure),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            UserAvatarView(
                              user: previewUser,
                              radius: 36,
                              showCameraBadge: true,
                              onTap: _showAvatarPickerModal,
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _showAvatarPickerModal,
                              child: const Text(
                                'Choisir ma photo / avatar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaire,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Vous êtes :',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'Passager',
                              icon: Icons.person_outline_rounded,
                              isSelected: _selectedRole == UserRole.passager,
                              onTap: () => setState(() => _selectedRole = UserRole.passager),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'Conducteur',
                              icon: Icons.directions_car_outlined,
                              isSelected: _selectedRole == UserRole.conducteur,
                              onTap: () => setState(() => _selectedRole = UserRole.conducteur),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Prénom', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _prenomController,
                                  decoration: _buildInputDecoration('Prénom', Icons.person_outline),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nom', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nomController,
                                  decoration: _buildInputDecoration('Nom', Icons.badge_outlined),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Text('Email universitaire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration('prenom.nom@esprit.tn', Icons.school_outlined),
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

                      const Text('Numéro de téléphone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.bordure),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                items: kCountryCodes.map((country) {
                                  return DropdownMenuItem<String>(
                                    value: country.code,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(country.flag, style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 6),
                                        Text(
                                          country.code,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCountryCode = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration('20 123 456', Icons.phone_android_outlined),
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
                      const SizedBox(height: 14),

                      const Text('Gouvernorat (24 régions de Tunisie)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bordure),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: kTunisianGovernoratesAndUniversities.containsKey(_selectedGouvernorat)
                                ? _selectedGouvernorat
                                : 'Tunis',
                            items: kTunisianGovernoratesAndUniversities.keys.map((gov) {
                              return DropdownMenuItem<String>(
                                value: gov,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primaire),
                                    const SizedBox(width: 8),
                                    Text(gov, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _onGouvernoratChanged,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Université / Faculté', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bordure),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: universitesDisponibles.contains(_selectedUniversite)
                                ? _selectedUniversite
                                : (universitesDisponibles.isNotEmpty ? universitesDisponibles.first : null),
                            items: universitesDisponibles.map((univ) {
                              return DropdownMenuItem<String>(
                                value: univ,
                                child: Text(
                                  univ,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedUniversite = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_selectedRole == UserRole.conducteur) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaireDoux.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaire.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.directions_car_filled_rounded, color: AppColors.primaire, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Détails du véhicule (Conducteur)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaire,
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
                                        const Text('Marque', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.bordure),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: kCarBrandsAndModels.containsKey(_selectedMarque)
                                                  ? _selectedMarque
                                                  : 'Peugeot',
                                              items: kCarBrandsAndModels.keys.map((b) {
                                                return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)));
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
                                        const Text('Modèle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.bordure),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: modelesDisponibles.contains(_selectedModele)
                                                  ? _selectedModele
                                                  : (modelesDisponibles.isNotEmpty ? modelesDisponibles.first : null),
                                              items: modelesDisponibles.map((m) {
                                                return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) setState(() => _selectedModele = val);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Couleur', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.bordure),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: kCarColors.contains(_selectedCouleur) ? _selectedCouleur : 'Noir',
                                              items: kCarColors.map((c) {
                                                return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) setState(() => _selectedCouleur = val);
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
                                        const Text('Immatriculation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _immatriculationController,
                                          decoration: _buildInputDecoration('220 TUN 1234', Icons.pin_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Places disponibles :',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [1, 2, 3, 4].map((count) {
                                      final isSel = _placesDisponibles == count;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: InkWell(
                                          onTap: () => setState(() => _placesDisponibles = count),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isSel ? AppColors.primaire : Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: isSel ? AppColors.primaire : AppColors.bordure),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  color: isSel ? Colors.white : const Color(0xFF374151),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
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
                        const SizedBox(height: 14),
                      ],

                      const Text('Mot de passe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _buildInputDecoration('••••••••', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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

                      const Text('Confirmer le mot de passe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: _buildInputDecoration('••••••••', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _acceptTerms,
                              activeColor: AppColors.primaire,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _acceptTerms = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'J\'accepte la charte de covoiturage étudiant et les CGU',
                              style: TextStyle(fontSize: 12, color: AppColors.texte2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Créer mon compte',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Déjà un compte ? ', style: TextStyle(color: AppColors.texte2, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Se connecter',
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
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.primaire, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaire, width: 2),
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaireDoux : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaire : AppColors.bordure,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaire : AppColors.texte2,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaire : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
