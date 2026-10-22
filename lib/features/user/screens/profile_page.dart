import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../models/user_model.dart';
import '../models/tunisia_data.dart';
import '../services/user_service.dart';
import 'login_page.dart';
import 'admin_dashboard_page.dart';
import 'widgets/user_avatar_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userService = UserService.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _userService,
      builder: (context, _) {
        final user = _userService.currentUser;

        if (user == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun utilisateur connecté.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaire),
                    child: const Text('Se connecter', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Mon Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: true,
            foregroundColor: const Color(0xFF1F2937),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primaire),
                tooltip: 'Modifier le profil',
                onPressed: () => _showEditProfileDialog(context, user),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildIdentityCard(context, user),
                const SizedBox(height: 18),

                _buildRoleSwitchCard(user),
                const SizedBox(height: 18),

                if (user.isConducteur) ...[
                  _buildVehicleCard(context, user),
                  const SizedBox(height: 18),
                ],

                _buildStatsCard(user),
                const SizedBox(height: 18),

                _buildMenuSection(context, user),
                const SizedBox(height: 22),

                _buildLogoutButton(context),
                const SizedBox(height: 14),

                if (!user.isAdmin) ...[
                  _buildDeleteAccountButton(context),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentityCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatarView(
                user: user,
                radius: 36,
                showCameraBadge: true,
                onTap: () => _showAvatarPickerModal(context),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nomComplet,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: AppColors.primaire, size: 18),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.texte2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 14, color: AppColors.texte2),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${user.universite} (${user.gouvernorat})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.texte2,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.bordure),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: AppColors.texte2),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        user.telephoneComplet,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoFond,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${user.note} / 5',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.infoTexte,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitchCard(UserModel user) {
    if (user.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC7D2FE),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF4F46E5),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte & Privilèges',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Administrateur Plateforme',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF312E81),
                    ),
                  ),
                  Text(
                    'Superviseur permanent (rôle fixe non modifiable)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF4338CA)),
                  SizedBox(width: 4),
                  Text(
                    'Fixe',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4338CA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isConducteur ? AppColors.accent.withValues(alpha: 0.4) : AppColors.primaire.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: user.isConducteur ? AppColors.accentDoux : AppColors.primaireDoux,
              shape: BoxShape.circle,
            ),
            child: Icon(
              user.isConducteur ? Icons.directions_car : Icons.person_pin_circle,
              color: user.isConducteur ? AppColors.accent : AppColors.primaire,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rôle actuel',
                  style: TextStyle(fontSize: 12, color: AppColors.texte2),
                ),
                const SizedBox(height: 2),
                Text(
                  user.role.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: user.isConducteur ? AppColors.accent : AppColors.primaire,
                  ),
                ),
                Text(
                  user.isConducteur
                      ? 'Vous proposez des places'
                      : 'Vous recherchez des trajets',
                  style: const TextStyle(fontSize: 11, color: AppColors.texte2),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: user.isConducteur,
            activeTrackColor: AppColors.accentDoux,
            inactiveThumbColor: AppColors.primaire,
            inactiveTrackColor: AppColors.primaireDoux,
            onChanged: (_) async {
              await _userService.toggleRole();
              if (!mounted) return;
              final currentRoleLabel = UserService.instance.currentUser?.role.label ?? '';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Mode changé en : $currentRoleLabel'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.directions_car_filled_outlined, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Mon Véhicule (Conducteur)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppColors.texte2),
                onPressed: () => _showEditVehicleDialog(context, user),
                tooltip: 'Modifier le véhicule',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Véhicule & Couleur', style: TextStyle(fontSize: 11, color: AppColors.texte2)),
                    const SizedBox(height: 2),
                    Text(
                      '${user.marqueVehicule ?? "Peugeot"} ${user.modeleVehicule ?? "208"} - ${user.couleurVehicule ?? "Noir"}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Immatriculation', style: TextStyle(fontSize: 11, color: AppColors.texte2)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      user.immatriculation ?? 'N/A',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Places proposées : ${user.placesDisponibles}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(UserModel user) {
    if (user.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _StatItem(
              label: 'Privilèges',
              value: 'Admin',
              icon: Icons.shield_outlined,
              color: Color(0xFF4F46E5),
            ),
            Container(width: 1, height: 36, color: AppColors.bordure),
            const _StatItem(
              label: 'Stockage',
              value: 'SQLite',
              icon: Icons.storage_rounded,
              color: Color(0xFF0D9488),
            ),
            Container(width: 1, height: 36, color: AppColors.bordure),
            const _StatItem(
              label: 'Modération',
              value: 'Active',
              icon: Icons.verified_user_outlined,
              color: Color(0xFF10B981),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Trajets',
            value: '${user.nombreTrajets}',
            icon: Icons.route_rounded,
            color: AppColors.primaire,
          ),
          Container(width: 1, height: 36, color: AppColors.bordure),
          _StatItem(
            label: 'Avis reçus',
            value: '${user.nombreTrajets * 2}',
            icon: Icons.rate_review_outlined,
            color: AppColors.accent,
          ),
          Container(width: 1, height: 36, color: AppColors.bordure),
          _StatItem(
            label: 'Note globale',
            value: '${user.note}',
            icon: Icons.star_half_rounded,
            color: Colors.amber[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, UserModel user) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bordure),
        ),
        child: Column(
          children: [
            if (user.isAdmin) ...[
              Container(
                color: const Color(0xFFF5F3FF),
                child: _MenuItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Espace Administration & Modération',
                  subtitle: 'Superviser, bannir, débloquer ou supprimer des comptes',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                    );
                  },
                ),
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFDDD6FE)),
            ],
            _MenuItem(
              icon: Icons.person_outline_rounded,
              title: 'Informations personnelles',
              subtitle: 'Nom, prénom, téléphone, université',
              onTap: () => _showEditProfileDialog(context, user),
            ),
            const Divider(height: 1, indent: 56, color: AppColors.bordure),
            _MenuItem(
              icon: Icons.security_outlined,
              title: 'Sécurité & Mot de passe',
              subtitle: 'Modifier votre mot de passe',
              onTap: () => _showChangePasswordDialog(context, user),
            ),
            const Divider(height: 1, indent: 56, color: AppColors.bordure),
            _MenuItem(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications & Alertes',
              subtitle: 'Trajets, messages, réservations',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications de covoiturage activées.')),
                );
              },
            ),
            const Divider(height: 1, indent: 56, color: AppColors.bordure),
            _MenuItem(
              icon: Icons.help_outline_rounded,
              title: 'Aide & Support Étudiant',
              subtitle: 'Numéros d\'urgence (197, 198) & Charte',
              onTap: () => _showHelpAndSupportModal(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutConfirmation(context),
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
      label: const Text(
        'Se déconnecter',
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        side: const BorderSide(color: Colors.redAccent, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 46),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _showDeleteAccountConfirmation(context),
      icon: const Icon(Icons.delete_forever_rounded, color: Colors.grey, size: 18),
      label: const Text(
        'Supprimer mon compte définitivement',
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Déconnexion'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre compte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: AppColors.texte2)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(ctx).pop();
              await _userService.logout();
              if (!mounted) return;
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Supprimer mon compte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Attention : Cette action est irréversible. Toutes vos informations personnelles, vos trajets et vos avis seront définitivement effacés.',
          style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: AppColors.texte2)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              final success = await _userService.deleteAccount();
              if (!mounted) return;
              if (success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Votre compte a été supprimé avec succès.'),
                    backgroundColor: Colors.red,
                  ),
                );
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGalleryOrComputer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        await _userService.updateAvatar(image.path);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour depuis votre appareil !'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showManualPathOrFallbackDialog(context);
      }
    }
  }

  void _showManualPathOrFallbackDialog(BuildContext context) {
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
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) {
                _userService.updateAvatar(text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaire, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal(BuildContext context) {
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
                  _pickImageFromGalleryOrComputer(context);
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
                  return InkWell(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(ctx).pop();
                      await _userService.updateAvatar(item.id);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Avatar changé en "${item.label}"')),
                      );
                    },
                    borderRadius: BorderRadius.circular(50),
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
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

  void _showChangePasswordDialog(BuildContext context, UserModel user) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? localError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.lock_reset_rounded, color: AppColors.primaire, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modifier mot de passe',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Saisissez votre mot de passe actuel puis définissez un nouveau mot de passe.',
                      style: TextStyle(fontSize: 12, color: AppColors.texte2),
                    ),
                    const SizedBox(height: 16),

                    if (localError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          localError!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ),

                    TextField(
                      controller: currentPassCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        helperText: 'Au moins 6 caractères',
                        prefixIcon: const Icon(Icons.key_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                        prefixIcon: const Icon(Icons.check_circle_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          final current = currentPassCtrl.text;
                          final newPass = newPassCtrl.text;
                          final confirm = confirmPassCtrl.text;

                          if (current.isEmpty) {
                            setDialogState(() => localError = 'Veuillez saisir votre mot de passe actuel.');
                            return;
                          }
                          if (newPass.length < 6) {
                            setDialogState(() => localError = 'Le nouveau mot de passe doit comporter au moins 6 caractères.');
                            return;
                          }
                          if (newPass != confirm) {
                            setDialogState(() => localError = 'Les nouveaux mots de passe ne correspondent pas.');
                            return;
                          }
                          if (current == newPass) {
                            setDialogState(() => localError = 'Le nouveau mot de passe doit être différent de l\'actuel.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            localError = null;
                          });

                          final success = await _userService.changePassword(
                            currentPassword: current,
                            newPassword: newPass,
                          );

                          if (!dialogCtx.mounted) return;

                          if (success) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Mot de passe modifié avec succès !'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } else {
                            setDialogState(() {
                              isLoading = false;
                              localError = _userService.errorMessage ?? 'Mot de passe actuel incorrect.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaire,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHelpAndSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaireDoux,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.primaire, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aide, Sécurité & Support',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Numéros d\'urgence en Tunisie et Charte de l\'application',
                              style: TextStyle(fontSize: 12, color: AppColors.texte2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '🚨 NUMÉROS D\'URGENCE EN TUNISIE (24H/24 - 7J/7)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildEmergencyCard(
                    context,
                    title: 'Police Secours',
                    number: '197',
                    description: 'Intervention d\'urgence, sécurité routière et ville',
                    color: const Color(0xFF1D4ED8),
                    icon: Icons.local_police_rounded,
                  ),
                  const SizedBox(height: 8),

                  _buildEmergencyCard(
                    context,
                    title: 'Protection Civile / Ambulance',
                    number: '198',
                    description: 'Accidents de la route, secours d\'urgence et pompiers',
                    color: const Color(0xFFDC2626),
                    icon: Icons.emergency_rounded,
                  ),
                  const SizedBox(height: 8),

                  _buildEmergencyCard(
                    context,
                    title: 'SAMU Tunisie',
                    number: '190',
                    description: 'Urgences médicales et assistance médicale urgente',
                    color: const Color(0xFF059669),
                    icon: Icons.local_hospital_rounded,
                  ),
                  const SizedBox(height: 8),

                  _buildEmergencyCard(
                    context,
                    title: 'Garde Nationale',
                    number: '193',
                    description: 'Sécurité sur les autoroutes et routes nationales',
                    color: const Color(0xFF4338CA),
                    icon: Icons.security_rounded,
                  ),
                  const SizedBox(height: 8),

                  _buildEmergencyCard(
                    context,
                    title: 'Numéro Vert SOS Tunisie',
                    number: '80 10 11 11',
                    description: 'Numéro vert gratuit d\'assistance et de signalement',
                    color: const Color(0xFF0D9488),
                    icon: Icons.phone_in_talk_rounded,
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    '📜 CONDITIONS & CHARTE DU COVOITURAGE ÉTUDIANT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildCharterRule(
                    number: '1',
                    title: 'Communauté Universitaire Exclusive',
                    description: 'L\'application est dédiée aux étudiants, enseignants et membres universitaires de Tunisie pour garantir confiance et sécurité.',
                  ),
                  _buildCharterRule(
                    number: '2',
                    title: 'Covoiturage Sans But Lucratif',
                    description: 'La participation demandée sert exclusivement à compenser les frais réels de carburant et de péage. Tout bénéfice commercial est proscrit.',
                  ),
                  _buildCharterRule(
                    number: '3',
                    title: 'Ponctualité & Respect',
                    description: 'Conducteurs et passagers s\'engagent à être présents aux points de rendez-vous universitaires fixés à l\'heure exacte.',
                  ),
                  _buildCharterRule(
                    number: '4',
                    title: 'Sécurité à Bord & Code de la Route',
                    description: 'Le port de la ceinture est obligatoire pour tous. Le conducteur respecte scrupuleusement les limitations de vitesse.',
                  ),
                  _buildCharterRule(
                    number: '5',
                    title: 'Annulation Courtoise (1h minimum)',
                    description: 'En cas d\'empêchement imprévu, prévenez vos compagnons de trajet au moins 1 heure à l\'avance via la messagerie.',
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.contact_support_outlined, color: AppColors.primaire, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Support ESPRIT & Covoiturage Tunisie',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Un problème avec un trajet ou une réclamation ? Contactez notre équipe étudiante :',
                          style: TextStyle(fontSize: 12, color: AppColors.texte2),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          'support@covoiturage-etudiant.tn',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaire,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmergencyCard(
    BuildContext context, {
    required String title,
    required String number,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.texte2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Numéro $number copié ! Prêt pour l\'appel.'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: color,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharterRule({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaireDoux,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaire),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.texte2, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final prenomCtrl = TextEditingController(text: user.prenom);
    final nomCtrl = TextEditingController(text: user.nom);
    final phoneCtrl = TextEditingController(text: user.telephone);
    String selectedGov = user.gouvernorat;
    String selectedUniv = user.universite;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final univs = kTunisianGovernoratesAndUniversities[selectedGov] ?? [];
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Modifier le profil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prenomCtrl,
                          decoration: const InputDecoration(labelText: 'Prénom'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: nomCtrl,
                          decoration: const InputDecoration(labelText: 'Nom'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: kTunisianGovernoratesAndUniversities.containsKey(selectedGov) ? selectedGov : 'Tunis',
                    decoration: const InputDecoration(labelText: 'Gouvernorat (24 régions)'),
                    items: kTunisianGovernoratesAndUniversities.keys.map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedGov = val;
                          final list = kTunisianGovernoratesAndUniversities[val] ?? [];
                          selectedUniv = list.isNotEmpty ? list.first : 'Autre établissement';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: univs.contains(selectedUniv) ? selectedUniv : (univs.isNotEmpty ? univs.first : null),
                    decoration: const InputDecoration(labelText: 'Université / Faculté'),
                    items: univs.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedUniv = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _userService.updateProfile(
                        prenom: prenomCtrl.text,
                        nom: nomCtrl.text,
                        telephone: phoneCtrl.text,
                        gouvernorat: selectedGov,
                        universite: selectedUniv,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Enregistrer les modifications'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, UserModel user) {
    String selectedMarque = user.marqueVehicule ?? 'Peugeot';
    String selectedModele = user.modeleVehicule ?? '208';
    String selectedCouleur = user.couleurVehicule ?? 'Noir';
    final immatCtrl = TextEditingController(text: user.immatriculation ?? '220 TUN 1234');
    int places = user.placesDisponibles;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final modeles = kCarBrandsAndModels[selectedMarque] ?? ['Autre modèle'];

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Modifier le véhicule',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                                  value: kCarBrandsAndModels.containsKey(selectedMarque) ? selectedMarque : 'Peugeot',
                                  items: kCarBrandsAndModels.keys.map((b) {
                                    return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedMarque = val;
                                        final list = kCarBrandsAndModels[val] ?? [];
                                        selectedModele = list.isNotEmpty ? list.first : 'Autre modèle';
                                      });
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
                                  value: modeles.contains(selectedModele) ? selectedModele : (modeles.isNotEmpty ? modeles.first : null),
                                  items: modeles.map((m) {
                                    return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedModele = val);
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
                                  value: kCarColors.contains(selectedCouleur) ? selectedCouleur : 'Noir',
                                  items: kCarColors.map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedCouleur = val);
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
                            TextField(
                              controller: immatCtrl,
                              decoration: const InputDecoration(
                                hintText: '220 TUN 1234',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      const Text('Nombre de places disponibles :', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [1, 2, 3, 4].map((count) {
                          final isSel = places == count;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => setModalState(() => places = count),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.accent : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSel ? AppColors.accent : AppColors.bordure),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isSel ? Colors.white : const Color(0xFF374151),
                                      fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _userService.updateProfile(
                        marqueVehicule: selectedMarque,
                        modeleVehicule: selectedModele,
                        couleurVehicule: selectedCouleur,
                        immatriculation: immatCtrl.text,
                        placesDisponibles: places,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Enregistrer le véhicule'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.texte2),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaire, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.texte2),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.texte2, size: 20),
      onTap: onTap,
    );
  }
}