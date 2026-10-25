import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../services/email_config.dart';
import '../services/user_service.dart';
import 'widgets/auth_map_background.dart';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mail_lock_rounded, color: AppColors.primaire),
              SizedBox(width: 8),
              Text('Configuration EmailJS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pour envoyer de vrais emails vers Gmail sans backend, renseignez vos identifiants EmailJS gratuits (depuis emailjs.com) :',
                  style: TextStyle(fontSize: 12, color: AppColors.texte2),
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
              child: const Text('Annuler', style: TextStyle(color: AppColors.texte2)),
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
                  const SnackBar(content: Text('Configuration EmailJS enregistrée !'), backgroundColor: AppColors.primaire),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaire),
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
        _errorMessage = 'Configuration EmailJS manquante. Cliquez sur l\'icône ⚙️ en haut à droite.';
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
          _infoMessage = 'Un e-mail de récupération a été expédié à $email.\nVérifiez votre boîte de réception Gmail (et vos spams).';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.primaire, size: 28),
              SizedBox(width: 10),
              Text('Succès', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Votre mot de passe a été mis à jour avec succès. Vous pouvez maintenant vous connecter.',
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primaire,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppColors.primaire),
                        tooltip: 'Configuration EmailJS',
                        onPressed: _showEmailConfigDialog,
                      ),
                      const BotanicalLeaf(size: 38),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaire,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentStep == 0
                    ? 'Enter your university email to receive a reset code'
                    : _currentStep == 1
                        ? 'Enter the 4-digit code sent to your email'
                        : 'Choose your new secure password',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.texte2,
                ),
              ),

              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF8B4B4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFC81E1E), size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF9B1C1C), fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_infoMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.creme,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sable),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primaire, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(color: AppColors.primaire, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_currentStep == 0) ...[
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'etudiant@esprit.tn',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(Icons.mail_outline_rounded, color: AppColors.texte2, size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    filled: true,
                    fillColor: AppColors.champFond,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendResetCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ] else if (_currentStep == 1) ...[
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold, color: AppColors.primaire),
                  decoration: InputDecoration(
                    hintText: '••••',
                    filled: true,
                    fillColor: AppColors.champFond,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleVerifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text('Change email', style: TextStyle(color: AppColors.texte2)),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _handleSendResetCode,
                      child: const Text('Resend code', style: TextStyle(color: AppColors.primaire, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(Icons.lock_outline_rounded, color: AppColors.texte2, size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.texte2),
                      onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    filled: true,
                    fillColor: AppColors.champFond,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm password',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(Icons.lock_outline_rounded, color: AppColors.texte2, size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.texte2),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    filled: true,
                    fillColor: AppColors.champFond,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Remembered your password? ', style: TextStyle(color: AppColors.texte2, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.primaire,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
