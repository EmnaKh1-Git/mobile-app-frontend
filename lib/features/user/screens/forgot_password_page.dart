import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../services/email_config.dart';
import '../services/user_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _userService = UserService.instance;

  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showEmailConfigDialog() {
    final serviceIdController = TextEditingController(text: EmailConfig.serviceId);
    final templateIdController = TextEditingController(text: EmailConfig.templateId);
    final publicKeyController = TextEditingController(text: EmailConfig.publicKey);
    final privateKeyController = TextEditingController(text: EmailConfig.privateKey);
    bool mockEnabled = EmailConfig.devModeMockEnabled;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mail_lock_rounded, color: AppColors.primaire),
              SizedBox(width: 8),
              Text('Configuration EmailJS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pour envoyer de vrais emails vers Gmail sans backend, renseignez vos identifiants EmailJS gratuits (depuis emailjs.com) :',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: serviceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Service ID',
                    hintText: 'ex: service_xxxxxx',
                    prefixIcon: Icon(Icons.miscellaneous_services_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: templateIdController,
                  decoration: const InputDecoration(
                    labelText: 'Template ID',
                    hintText: 'ex: template_xxxxxx',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: publicKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Public Key',
                    hintText: 'ex: user_xxxx ou clé publique',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: privateKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Private Key (Optionnel)',
                    hintText: 'Si activée dans Account > Security',
                    prefixIcon: Icon(Icons.lock_clock_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode Simulation locale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Affiche le code directement si aucun compte EmailJS n\'est configuré', style: TextStyle(fontSize: 11)),
                  value: mockEnabled,
                  onChanged: (val) {
                    setDialogState(() {
                      mockEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  EmailConfig.serviceId = serviceIdController.text.trim();
                  EmailConfig.templateId = templateIdController.text.trim();
                  EmailConfig.publicKey = publicKeyController.text.trim();
                  EmailConfig.privateKey = privateKeyController.text.trim();
                  EmailConfig.devModeMockEnabled = mockEnabled;
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configuration EmailJS enregistrée !')),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Veuillez saisir une adresse email valide.';
      });
      return;
    }

    if (!EmailConfig.isConfigured && !EmailConfig.devModeMockEnabled) {
      setState(() {
        _errorMessage = 'Configuration EmailJS manquante. Cliquez sur l\'icône ⚙️ en haut à droite pour renseigner vos identifiants ou activer le mode test.';
      });
      _showEmailConfigDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await _userService.sendPasswordResetCode(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _currentStep = 1;
        if (EmailConfig.devModeMockEnabled) {
          final code = _userService.getLatestCode(email) ?? '1234';
          _infoMessage = 'Mode simulation actif : Code généré : $code';
          _codeController.text = code;
        } else {
          _infoMessage = 'Un e-mail de récupération a été expédié à $email.\nVérifiez votre boîte de réception Gmail (et vos courriers indésirables / spams).';
          _codeController.clear();
        }
      });
    } else {
      setState(() {
        _errorMessage = _userService.errorMessage ?? 'Erreur lors de l\'envoi de l\'e-mail.';
      });
    }
  }

  void _handleVerifyCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez saisir le code reçu par email.';
      });
      return;
    }

    final isValid = _userService.verifyResetCode(_emailController.text, code);
    if (!isValid) {
      setState(() {
        _errorMessage = 'Code incorrect ou expiré. Veuillez vérifier votre boîte e-mail.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _currentStep = 2;
    });
  }

  Future<void> _handleResetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      setState(() {
        _errorMessage = 'Le mot de passe doit comporter au moins 6 caractères.';
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = 'Les mots de passe ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await _userService.resetPassword(
      email: _emailController.text,
      newPassword: newPass,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Succès'),
            ],
          ),
          content: const Text(
            'Votre mot de passe a été mis à jour avec succès. Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaire),
              child: const Text('Aller à la connexion', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = _userService.errorMessage ?? 'Erreur lors de la mise à jour.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mot de passe oublié',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF1F2937),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primaire),
            tooltip: 'Configuration EmailJS',
            onPressed: _showEmailConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primaireDoux,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 38,
                    color: AppColors.primaire,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _currentStep == 0
                    ? 'Réinitialisation du compte'
                    : _currentStep == 1
                        ? 'Vérification du code'
                        : 'Nouveau mot de passe',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _currentStep == 0
                    ? 'Entrez votre adresse email universitaire pour recevoir un code de sécurité.'
                    : _currentStep == 1
                        ? 'Saisissez le code de sécurité reçu sur votre boîte Gmail.'
                        : 'Définissez votre nouveau mot de passe sécurisé.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.texte2),
              ),
              const SizedBox(height: 24),

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

              if (_infoMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoFond,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaire.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.infoTexte, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(color: AppColors.infoTexte, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bordure),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStep == 0) ...[
                      const Text(
                        'Email universitaire',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'etudiant@esprit.tn',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaire),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendResetCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Envoyer le code de vérification', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ] else if (_currentStep == 1) ...[
                      const Text(
                        'Code de vérification',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '••••',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bordure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _handleVerifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Valider le code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _currentStep = 0),
                            child: const Text('Modifier l\'email', style: TextStyle(color: AppColors.texte2)),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _handleSendResetCode,
                            child: const Text('Renvoyer l\'e-mail', style: TextStyle(color: AppColors.primaire, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Nouveau mot de passe',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaire),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Confirmer le mot de passe',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaire),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Enregistrer le nouveau mot de passe', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.primaire),
                  label: const Text(
                    'Retour à la page de connexion',
                    style: TextStyle(color: AppColors.primaire, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
