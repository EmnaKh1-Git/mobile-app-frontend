import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../models/user_model.dart';

class AvatarItem {
  final String id;
  final String label;
  final Color color;
  final IconData icon;

  const AvatarItem({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
  });
}

const List<AvatarItem> kAvatarPresets = [
  AvatarItem(id: 'avatar_conducteur', label: 'Conducteur', color: Color(0xFFFF7A59), icon: Icons.directions_car),
  AvatarItem(id: 'avatar_etudiant', label: 'Étudiant', color: Color(0xFF3155D9), icon: Icons.school),
  AvatarItem(id: 'avatar_etudiante', label: 'Étudiante', color: Color(0xFF9333EA), icon: Icons.face_3),
  AvatarItem(id: 'avatar_voyageur', label: 'Voyageur', color: Color(0xFF0D9488), icon: Icons.travel_explore),
];

class UserAvatarView extends StatelessWidget {
  final UserModel? user;
  final double radius;
  final VoidCallback? onTap;
  final bool showCameraBadge;

  const UserAvatarView({
    super.key,
    required this.user,
    this.radius = 32,
    this.onTap,
    this.showCameraBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarId = user?.avatarUrl;
    AvatarItem? matchedPreset;

    String? normalizedId = avatarId;
    if (avatarId == 'avatar_1') normalizedId = 'avatar_etudiant';
    if (avatarId == 'avatar_2') normalizedId = 'avatar_conducteur';
    if (avatarId == 'avatar_3') normalizedId = 'avatar_etudiante';
    if (avatarId == 'avatar_5') normalizedId = 'avatar_voyageur';

    if (normalizedId != null && normalizedId.isNotEmpty) {
      try {
        matchedPreset = kAvatarPresets.firstWhere((p) => p.id == normalizedId);
      } catch (_) {
        matchedPreset = null;
      }
    }

    final isDriver = user?.isConducteur == true;
    final primaryColor = matchedPreset?.color ?? (isDriver ? AppColors.accent : AppColors.primaire);

    bool isLocalFile = false;
    File? localImageFile;
    if (avatarId != null && avatarId.isNotEmpty && matchedPreset == null) {
      try {
        final f = File(avatarId);
        if (f.existsSync()) {
          isLocalFile = true;
          localImageFile = f;
        }
      } catch (_) {}
    }

    final isNetworkUrl = avatarId != null &&
        (avatarId.startsWith('http://') || avatarId.startsWith('https://'));

    Widget innerContent;

    if (isLocalFile && localImageFile != null) {
      innerContent = ClipOval(
        child: Image.file(
          localImageFile,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackInitials(radius),
        ),
      );
    } else if (isNetworkUrl) {
      innerContent = ClipOval(
        child: Image.network(
          avatarId,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackInitials(radius),
        ),
      );
    } else if (matchedPreset != null) {
      innerContent = Center(
        child: Icon(
          matchedPreset.icon,
          size: radius * 1.05,
          color: Colors.white,
        ),
      );
    } else {
      innerContent = _buildFallbackInitials(radius);
    }

    final avatarCircle = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: innerContent,
    );

    if (!showCameraBadge) {
      return GestureDetector(
        onTap: onTap,
        child: avatarCircle,
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: avatarCircle,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primaire,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitials(double radius) {
    final initials = user != null && user!.prenom.isNotEmpty
        ? '${user!.prenom[0]}${user!.nom.isNotEmpty ? user!.nom[0] : ""}'.toUpperCase()
        : 'U';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
