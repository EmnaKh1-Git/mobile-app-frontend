import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'login_page.dart';

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
                // Header Avatar & Identity Card
                _buildIdentityCard(context, user),
                const SizedBox(height: 20),

                // Switch Role Card (Passager <-> Conducteur)
                _buildRoleSwitchCard(user),
                const SizedBox(height: 20),

                // Vehicle Info Card if Driver
                if (user.isConducteur) ...[
                  _buildVehicleCard(user),
                  const SizedBox(height: 20),
                ],

                // Quick Stats Overview
                _buildStatsCard(user),
                const SizedBox(height: 20),

                // Options Menu List
                _buildMenuSection(context, user),
                const SizedBox(height: 24),

                // Logout Button
                _buildLogoutButton(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Identity Card with Avatar, Name, Email, University, Rating Badge
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
              // Circle Avatar with Initials
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaire, AppColors.primaire.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaire.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${user.prenom.isNotEmpty ? user.prenom[0] : ""}${user.nom.isNotEmpty ? user.nom[0] : ""}'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Email
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
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.texte2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 14, color: AppColors.texte2),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.universite,
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

          // Contact details strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.texte2),
                  const SizedBox(width: 6),
                  Text(
                    user.telephone,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoFond,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
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

  /// Switch role passager / conducteur card
  Widget _buildRoleSwitchCard(UserModel user) {
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

  /// Vehicle Info Card
  Widget _buildVehicleCard(UserModel user) {
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
          const Row(
            children: [
              Icon(Icons.directions_car_filled_outlined, color: AppColors.primaire, size: 20),
              SizedBox(width: 8),
              Text(
                'Mon Véhicule (Conducteur)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Modèle', style: TextStyle(fontSize: 11, color: AppColors.texte2)),
                  Text(
                    user.modeleVehicule ?? 'Non renseigné',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Immatriculation', style: TextStyle(fontSize: 11, color: AppColors.texte2)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        ],
      ),
    );
  }

  /// Quick Stats Overview
  Widget _buildStatsCard(UserModel user) {
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

  /// Settings Menu
  Widget _buildMenuSection(BuildContext context, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        children: [
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Option de sécurité bientôt disponible.')),
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.bordure),
          _MenuItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications & Alertes',
            subtitle: 'Trajets, messages, demandes',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Préférences de notification enregistrées.')),
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.bordure),
          _MenuItem(
            icon: Icons.help_outline_rounded,
            title: 'Aide & Support Étudiant',
            subtitle: 'FAQ, signaler un problème',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support étudiant disponible 24/7.')),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Logout Button
  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutConfirmation(context),
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
      label: const Text(
        'Se déconnecter',
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 48),
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

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final prenomCtrl = TextEditingController(text: user.prenom);
    final nomCtrl = TextEditingController(text: user.nom);
    final phoneCtrl = TextEditingController(text: user.telephone);
    final univCtrl = TextEditingController(text: user.universite);
    final vehiculeCtrl = TextEditingController(text: user.modeleVehicule ?? '');
    final immatCtrl = TextEditingController(text: user.immatriculation ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              TextField(
                controller: prenomCtrl,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: univCtrl,
                decoration: const InputDecoration(labelText: 'Université'),
              ),
              if (user.isConducteur) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: vehiculeCtrl,
                  decoration: const InputDecoration(labelText: 'Modèle Véhicule'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: immatCtrl,
                  decoration: const InputDecoration(labelText: 'Immatriculation'),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await _userService.updateProfile(
                    prenom: prenomCtrl.text,
                    nom: nomCtrl.text,
                    telephone: phoneCtrl.text,
                    universite: univCtrl.text,
                    modeleVehicule: vehiculeCtrl.text,
                    immatriculation: immatCtrl.text,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaire,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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