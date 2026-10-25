import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// URL d'une carte stylisée / vue aérienne de route dans la nature
/// assortie au thème vert et covoiturage de l'application.
const String kAuthMapImageUrl =
    'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=1400&q=80';

/// Deuxième URL alternative de route / carte routière verdoyante
const String kAuthAerialRoadUrl =
    'https://images.unsplash.com/photo-1508873696983-2df5293cb32f?auto=format&fit=crop&w=1400&q=80';

/// Clipper créant la vague organique courbée en bas de l'en-tête,
/// identique à la maquette fournie (Screen 2).
class AuthWaveClipper extends CustomClipper<Path> {
  const AuthWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 48);

    // Première courbe fluide depuis la gauche
    final firstControlPoint = Offset(size.width * 0.28, size.height + 4);
    final firstEndPoint = Offset(size.width * 0.58, size.height - 24);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Deuxième courbe douce vers la droite
    final secondControlPoint = Offset(size.width * 0.84, size.height - 46);
    final secondEndPoint = Offset(size.width, size.height - 18);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// En-tête héro avec découpe en vague organique et image de carte / route
class AuthHeroHeader extends StatelessWidget {
  final double height;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? overlayContent;

  const AuthHeroHeader({
    super.key,
    this.height = 270,
    this.onBack,
    this.showBackButton = true,
    this.overlayContent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Image découpée par la vague organique
          ClipPath(
            clipper: const AuthWaveClipper(),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de fond (Carte / Route verte)
                  Image.network(
                    kAuthMapImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _OfflineVectorMap(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const _OfflineVectorMap();
                    },
                  ),

                  // Dégradé vert élégant assorti à la palette
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaire.withValues(alpha: 0.55),
                          AppColors.primaireFonce.withValues(alpha: 0.70),
                          AppColors.primaire.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Tracé vectoriel subtil de route sur la carte
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HeaderRoadRoutePainter(),
                    ),
                  ),

                  ?overlayContent,
                ],
              ),
            ),
          ),

          // Bouton retour flottant circulaire (comme dans la maquette)
          if (showBackButton)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              left: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.primaire,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Décoration botanique à double feuille, fidèle à la maquette
class BotanicalLeaf extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;

  const BotanicalLeaf({
    super.key,
    this.size = 38,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BotanicalLeafPainter(
          primaryColor: primaryColor ?? AppColors.primaire,
          secondaryColor: secondaryColor ?? AppColors.accent,
        ),
      ),
    );
  }
}

class _BotanicalLeafPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _BotanicalLeafPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Tige de la feuille
    final stemPath = Path()
      ..moveTo(w * 0.15, h * 0.90)
      ..quadraticBezierTo(w * 0.40, h * 0.65, w * 0.70, h * 0.25);

    final stemPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(stemPath, stemPaint);

    // Feuille principale (grande feuille inclinée vers le haut à droite)
    final mainLeaf = Path()
      ..moveTo(w * 0.35, h * 0.70)
      ..cubicTo(w * 0.30, h * 0.40, w * 0.55, h * 0.15, w * 0.92, h * 0.12)
      ..cubicTo(w * 0.88, h * 0.45, w * 0.65, h * 0.70, w * 0.35, h * 0.70);

    final mainLeafPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(mainLeaf, mainLeafPaint);

    // Nervure centrale de la grande feuille
    final vein = Path()
      ..moveTo(w * 0.38, h * 0.68)
      ..quadraticBezierTo(w * 0.60, h * 0.45, w * 0.90, h * 0.14);

    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(vein, veinPaint);

    // Deuxième petite feuille
    final smallLeaf = Path()
      ..moveTo(w * 0.32, h * 0.75)
      ..cubicTo(w * 0.15, h * 0.62, w * 0.22, h * 0.45, w * 0.46, h * 0.46)
      ..cubicTo(w * 0.45, h * 0.62, w * 0.40, h * 0.72, w * 0.32, h * 0.75);

    final smallLeafPaint = Paint()
      ..shader = LinearGradient(
        colors: [secondaryColor, AppColors.soutien],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(smallLeaf, smallLeafPaint);
  }

  @override
  bool shouldRepaint(covariant _BotanicalLeafPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}

/// Rangée de boutons sociaux comme sur le 3ème écran de la maquette
class SocialLoginRow extends StatelessWidget {
  final VoidCallback? onGoogleTap;
  final VoidCallback? onFacebookTap;
  final VoidCallback? onAppleTap;
  final bool isLoading;

  const SocialLoginRow({
    super.key,
    this.onGoogleTap,
    this.onFacebookTap,
    this.onAppleTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 1, color: AppColors.bordure)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.texte2.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: AppColors.bordure)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialCircleButton(
              onTap: onFacebookTap ?? () => _showSocialInfo(context, 'Facebook'),
              child: const Icon(
                Icons.facebook_rounded,
                color: Color(0xFF1877F2),
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            _SocialCircleButton(
              onTap: isLoading ? null : onGoogleTap,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaire,
                      ),
                    )
                  : const _GoogleIconSvg(),
            ),
            const SizedBox(width: 18),
            _SocialCircleButton(
              onTap: onAppleTap ?? () => _showSocialInfo(context, 'Apple'),
              child: const Icon(
                Icons.apple_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSocialInfo(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connexion $provider disponible avec votre compte étudiant.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaire,
      ),
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SocialCircleButton({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bordure),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GoogleIconSvg extends StatelessWidget {
  const _GoogleIconSvg();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 21,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}

/// Fond de carte hors-ligne vectoriel au design vert covoiturage
class _OfflineVectorMap extends StatelessWidget {
  const _OfflineVectorMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF225712),
            Color(0xFF2A7C13),
            Color(0xFF1E5B0E),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _MapRoadsPainter(),
      ),
    );
  }
}

class _MapRoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thinRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final p1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.2,
        size.width * 0.65,
        size.height * 0.6,
        size.width,
        size.height * 0.45,
      );
    canvas.drawPath(p1, roadPaint);

    final p2 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.5,
        size.width * 0.8,
        size.height,
      );
    canvas.drawPath(p2, thinRoadPaint);

    // Repères et points lumineux de trajet
    final pinPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.25), 5, pinPaint);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.52), 6, pinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderRoadRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.10, size.height * 0.65)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.35,
        size.width * 0.60,
        size.height * 0.55,
        size.width * 0.88,
        size.height * 0.30,
      );
    canvas.drawPath(path, routePaint);

    final dotPaint = Paint()..color = AppColors.creme;
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.65), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.30), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// AuthMapBackground pour pages en plein écran (conservé pour compatibilité)
class AuthMapBackground extends StatelessWidget {
  const AuthMapBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            kAuthMapImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _OfflineVectorMap(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaire.withValues(alpha: 0.85),
                  AppColors.primaire.withValues(alpha: 0.65),
                  AppColors.fond.withValues(alpha: 0.95),
                  AppColors.fond,
                ],
                stops: const [0, 0.35, 0.70, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
