import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../models/tunisia_data.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/email_service.dart';

class GoogleAccountInfo {
  final String email;
  final String prenom;
  final String nom;
  final String avatarId;
  final UserModel? fullUser;

  const GoogleAccountInfo({
    required this.email,
    required this.prenom,
    required this.nom,
    required this.avatarId,
    this.fullUser,
  });
}

enum _GoogleFlowStep {
  emailInput,
  codeVerification,
  profileCompletion,
}

class GoogleSignInModal extends StatefulWidget {
  final ValueChanged<GoogleAccountInfo> onAccountSelected;

  const GoogleSignInModal({
    super.key,
    required this.onAccountSelected,
  });

  static Future<GoogleAccountInfo?> show(BuildContext context) {
    return Navigator.of(context).push<GoogleAccountInfo>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFF0F4F9),
          body: GoogleSignInModal(
            onAccountSelected: (acc) => Navigator.of(ctx).pop(acc),
          ),
        ),
      ),
    );
  }

  @override
  State<GoogleSignInModal> createState() => _GoogleSignInModalState();
}

class _GoogleSignInModalState extends State<GoogleSignInModal> {
  final _emailService = EmailService.instance;
  final _db = DatabaseService.instance;

  _GoogleFlowStep _currentStep = _GoogleFlowStep.emailInput;

  final _emailCtrl = TextEditingController();
  List<GoogleAccountInfo> _savedDeviceAccounts = [];

  final _codeCtrl = TextEditingController();
  String? _expectedCode;

  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _immatCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.passager;
  String _selectedGov = kTunisianGovernoratesAndUniversities.keys.first;
  String _selectedUniv = 'ESPRIT (Pôle Ghazela)';
  String _selectedMarque = 'Peugeot';
  String _selectedModele = '208';
  final String _selectedCouleur = 'Blanc';
  final String _selectedAvatarId = 'avatar_etudiant';

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final allUsers = await _db.getAllUsers();
      final googleUsers = allUsers
          .where((u) => u.email.endsWith('@gmail.com'))
          .map((u) => GoogleAccountInfo(
                email: u.email,
                prenom: u.prenom,
                nom: u.nom,
                avatarId: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                    ? u.avatarUrl!
                    : 'avatar_etudiant',
                fullUser: u,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _savedDeviceAccounts = googleUsers;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _phoneCtrl.dispose();
    _immatCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode({String? targetEmail}) async {
    final email = (targetEmail ?? _emailCtrl.text).trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Saisissez une adresse Gmail valide.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _emailService.sendRecoveryEmail(
      recipientEmail: email,
      recipientName: 'Utilisateur Google',
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _expectedCode = result.code;
      _emailCtrl.text = email;
      _currentStep = _GoogleFlowStep.codeVerification;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Un code de confirmation a été envoyé à $email'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _verifyCodeAndProceed() async {
    final enteredCode = _codeCtrl.text.trim();
    if (enteredCode.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir le code reçu sur votre e-mail.');
      return;
    }

    if (enteredCode != _expectedCode) {
      setState(() => _errorMessage = 'Code incorrect. Vérifiez votre boîte de réception Gmail.');
      return;
    }

    final email = _emailCtrl.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final existingUser = await _db.getUserByEmail(email);

    if (!mounted) return;

    if (existingUser != null) {
      widget.onAccountSelected(
        GoogleAccountInfo(
          email: existingUser.email,
          prenom: existingUser.prenom,
          nom: existingUser.nom,
          avatarId: existingUser.avatarUrl ?? 'avatar_etudiant',
          fullUser: existingUser,
        ),
      );
    } else {
      final prefix = email.split('@').first;
      final parts = prefix.split(RegExp(r'[._-]'));
      final defaultPrenom = parts.isNotEmpty && parts[0].isNotEmpty
          ? parts[0][0].toUpperCase() + parts[0].substring(1)
          : '';
      final defaultNom = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1][0].toUpperCase() + parts[1].substring(1)
          : '';

      _prenomCtrl.text = defaultPrenom;
      _nomCtrl.text = defaultNom;

      setState(() {
        _isLoading = false;
        _currentStep = _GoogleFlowStep.profileCompletion;
      });
    }
  }

  Future<void> _submitProfileCompletion() async {
    final prenom = _prenomCtrl.text.trim();
    final nom = _nomCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (prenom.isEmpty || nom.isEmpty) {
      setState(() => _errorMessage = 'Veuillez renseigner votre prénom et votre nom.');
      return;
    }

    if (phone.isEmpty || phone.length < 8) {
      setState(() => _errorMessage = 'Veuillez saisir un numéro de téléphone valide (8 chiffres).');
      return;
    }

    if (_selectedRole == UserRole.conducteur && _immatCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Veuillez indiquer l\'immatriculation de votre véhicule.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim().toLowerCase();

    final newUser = UserModel(
      id: 'usr_google_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom,
      prenom: prenom,
      email: email,
      telephone: phone,
      indicatifTel: '+216',
      role: _selectedRole,
      avatarUrl: _selectedAvatarId,
      gouvernorat: _selectedGov,
      universite: _selectedUniv,
      note: 5.0,
      nombreTrajets: 0,
      marqueVehicule: _selectedRole == UserRole.conducteur ? _selectedMarque : null,
      modeleVehicule: _selectedRole == UserRole.conducteur ? _selectedModele : null,
      couleurVehicule: _selectedRole == UserRole.conducteur ? _selectedCouleur : null,
      immatriculation: _selectedRole == UserRole.conducteur ? _immatCtrl.text.trim() : null,
      placesDisponibles: _selectedRole == UserRole.conducteur ? 3 : 0,
      dateInscription: DateTime.now(),
    );

    await _db.insertUser(newUser, 'GoogleAuthSecure123!');

    if (!mounted) return;

    widget.onAccountSelected(
      GoogleAccountInfo(
        email: email,
        prenom: prenom,
        nom: nom,
        avatarId: _selectedAvatarId,
        fullUser: newUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDADCE0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFE8F0FE),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                        minHeight: 3,
                      ),
                    ),

                  Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                          TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                          TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                          TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE8E6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF5C2C7)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFC5221F), fontSize: 13),
                      ),
                    ),

                  if (_currentStep == _GoogleFlowStep.emailInput) ...[
                    const Text(
                      'Connexion avec Google',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF202124)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Un e-mail de confirmation avec code sera envoyé à votre adresse',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
                    ),
                    const SizedBox(height: 20),

                    if (_savedDeviceAccounts.isNotEmpty) ...[
                      const Text(
                        'Comptes Google enregistrés sur cet appareil :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 8),
                      ..._savedDeviceAccounts.map((acc) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDADCE0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () => _sendVerificationCode(targetEmail: acc.email),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF1A73E8),
                              child: Text(
                                acc.prenom.isNotEmpty ? acc.prenom[0].toUpperCase() : 'G',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text('${acc.prenom} ${acc.nom}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(acc.email, style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF5F6368)),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFDADCE0)),
                      const SizedBox(height: 8),
                    ],

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Votre adresse Gmail',
                        hintText: 'mon.compte@gmail.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF1A73E8)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendVerificationCode(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annuler', style: TextStyle(color: Color(0xFF1A73E8))),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _sendVerificationCode(),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Envoyer le code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_currentStep == _GoogleFlowStep.codeVerification) ...[
                    const Text(
                      'Validation de votre Gmail',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF202124)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Un e-mail contenant un code à 6 chiffres a été envoyé à :\n${_emailCtrl.text.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368), height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _verifyCodeAndProceed(),
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _isLoading ? null : () => _sendVerificationCode(),
                        child: const Text('Renvoyer un nouveau code', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _currentStep = _GoogleFlowStep.emailInput),
                          child: const Text('Changer d\'adresse', style: TextStyle(color: Color(0xFF5F6368))),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCodeAndProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Confirmer le code'),
                        ),
                      ],
                    ),
                  ],

                  if (_currentStep == _GoogleFlowStep.profileCompletion) ...[
                    const Text(
                      'Compléter votre profil',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF202124)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Renseignez vos vraies informations universitaires',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prenomCtrl,
                            decoration: const InputDecoration(labelText: 'Prénom *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _nomCtrl,
                            decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (ex: 20123456) *',
                        prefixText: '+216 ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Passager')),
                            selected: _selectedRole == UserRole.passager,
                            onSelected: (_) => setState(() => _selectedRole = UserRole.passager),
                            selectedColor: AppColors.primaireDoux,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Conducteur')),
                            selected: _selectedRole == UserRole.conducteur,
                            onSelected: (_) => setState(() => _selectedRole = UserRole.conducteur),
                            selectedColor: AppColors.accentDoux,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedGov,
                      decoration: const InputDecoration(labelText: 'Gouvernorat', border: OutlineInputBorder(), isDense: true),
                      items: kTunisianGovernoratesAndUniversities.keys.map((gov) => DropdownMenuItem(value: gov, child: Text(gov, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedGov = val;
                            final univs = kTunisianGovernoratesAndUniversities[val] ?? [];
                            _selectedUniv = univs.isNotEmpty ? univs.first : 'Autre université';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedUniv,
                      decoration: const InputDecoration(labelText: 'Université / Institut', border: OutlineInputBorder(), isDense: true),
                      items: (kTunisianGovernoratesAndUniversities[_selectedGov] ?? [_selectedUniv]).map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUniv = val);
                      },
                    ),

                    if (_selectedRole == UserRole.conducteur) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedMarque,
                              decoration: const InputDecoration(labelText: 'Marque', border: OutlineInputBorder(), isDense: true),
                              items: kCarBrandsAndModels.keys.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedMarque = val;
                                    final models = kCarBrandsAndModels[val] ?? [];
                                    _selectedModele = models.isNotEmpty ? models.first : 'Autre';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedModele,
                              decoration: const InputDecoration(labelText: 'Modèle', border: OutlineInputBorder(), isDense: true),
                              items: (kCarBrandsAndModels[_selectedMarque] ?? [_selectedModele]).map((mod) => DropdownMenuItem(value: mod, child: Text(mod, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedModele = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _immatCtrl,
                        decoration: const InputDecoration(labelText: 'Immatriculation (ex: 215 TUN 4321) *', border: OutlineInputBorder(), isDense: true),
                      ),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitProfileCompletion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Valider et Créer mon compte', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFDADCE0)),
                  const SizedBox(height: 8),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Français (France)', style: TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                      Row(
                        children: [
                          Text('Aide', style: TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                          SizedBox(width: 10),
                          Text('Confidentialité', style: TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                          SizedBox(width: 10),
                          Text('Conditions', style: TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
