import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../user/screens/login_page.dart';
import '../../user/screens/register_page.dart';
import '../../user/screens/widgets/auth_map_background.dart';

// ============================================================================
// ÉCRAN 1 : SPLASH SCREEN PROFESSIONNEL AVEC LA NOUVELLE PALETTE BOTANIQUE
// ============================================================================

class AppStartupPage extends StatefulWidget {
  const AppStartupPage({super.key});

  @override
  State<AppStartupPage> createState() => _AppStartupPageState();
}

class _AppStartupPageState extends State<AppStartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _didNavigate = false;
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _entrance.value = 1;
        _openOnboarding();
        return;
      }
      _entrance.forward();
      _startupTimer = Timer(
        const Duration(milliseconds: 1950),
        _openOnboarding,
      );
    });
  }

  void _openOnboarding() {
    _startupTimer?.cancel();
    _startupTimer = null;
    if (!mounted || _didNavigate) return;
    _didNavigate = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, _, _) => const AppIntroPage(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaireFonce,
      body: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final reveal = Curves.easeOutCubic.transform(_entrance.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Dégradé vert profond élégant (rgb(42, 124, 19))
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF13380A),
                      Color(0xFF1D5A0F),
                      Color(0xFF2A7C13),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                ),
              ),

              // Halo lumineux d'ambiance avec les nouvelles couleurs
              Positioned(
                top: -120,
                right: -100,
                child: _Glow(
                  size: 380,
                  color: AppColors.accent.withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                bottom: -180,
                left: -130,
                child: _Glow(
                  size: 420,
                  color: AppColors.sable.withValues(alpha: 0.14),
                ),
              ),

              // Tracé animé de route cartographique
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashRoutePainter(progress: reveal),
                ),
              ),

              // Contenu principal centré
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: reveal,
                      child: Transform.translate(
                        offset: Offset(0, (1 - reveal) * 22),
                        child: Transform.scale(
                          scale: 0.88 + 0.12 * reveal,
                          child: Column(
                            children: [
                              // Badge Logo en verre dépoli avec icône voiture & feuille
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(38),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.25),
                                      blurRadius: 38,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const CustomPaint(
                                  painter: _SplashLogoPainter(),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'Covoiturage Étudiant',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Votre trajet, notre destination verte.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.creme.withValues(alpha: 0.88),
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 38),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.accent,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'En route ensemble',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashLogoPainter extends CustomPainter {
  const _SplashLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * 0.22, size.height * 0.72)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.46,
        size.width * 0.64,
        size.height * 0.76,
        size.width * 0.78,
        size.height * 0.28,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Points de départ et d'arrivée
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.72),
      7,
      Paint()..color = AppColors.creme,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.28),
      7,
      Paint()..color = AppColors.accent,
    );

    // Véhicule covoiturage stylisé
    final car = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.51, size.height * 0.51),
        width: size.width * 0.36,
        height: size.height * 0.20,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(car, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.43,
          size.height * 0.43,
          size.width * 0.18,
          size.height * 0.08,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = AppColors.primaire,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashLogoPainter oldDelegate) => false;
}

class _SplashRoutePainter extends CustomPainter {
  const _SplashRoutePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.78)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.60,
        size.width * 0.65,
        size.height * 0.92,
        size.width * 1.05,
        size.height * 0.60,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashRoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// ÉCRAN 2 : ONBOARDING PROFESSIONNEL (INCLUANT LE DESIGN DU SCREEN 1 MAQUETTE)
// ============================================================================

class AppIntroPage extends StatefulWidget {
  const AppIntroPage({super.key});

  @override
  State<AppIntroPage> createState() => _AppIntroPageState();
}

class _AppIntroPageState extends State<AppIntroPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _motion;
  int _currentPage = 0;

  static const _slides = [
    _IntroContent(
      title: 'Le trajet devient plus simple',
      description:
          'Trouvez facilement des conducteurs et des passagers étudiants qui partagent votre destination.',
      kind: _IllustrationKind.route,
    ),
    _IntroContent(
      title: 'Voyagez mieux, dépensez moins',
      description:
          'Partagez les frais de route, économisez sur vos déplacements et profitez d\'une solution écoresponsable.',
      kind: _IllustrationKind.savings,
    ),
    _IntroContent(
      title: 'La confiance à chaque trajet',
      description:
          'Comptes étudiants vérifiés, avis et trajets organisés en toute sérénité au sein du campus.',
      kind: _IllustrationKind.trust,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page > _slides.length) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _finishToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  void _finishToRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Total pages = 1 Cover Screen (Screen 1 de la maquette) + 3 Slides
    const totalPages = 4;
    final compact = MediaQuery.sizeOf(context).height < 720;

    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          // ------------------------------------------------------------------
          // SLIDE 0 : EXACT SCREEN 1 DE LA MAQUETTE (Plein écran hero + bouton translucide)
          // ------------------------------------------------------------------
          _WelcomeHeroCoverSlide(
            onSignIn: _finishToLogin,
            onCreateAccount: _finishToRegister,
            onExplore: () => _goTo(1),
          ),

          // ------------------------------------------------------------------
          // SLIDE 1, 2, 3 : Présentation interactive des fonctionnalités
          // ------------------------------------------------------------------
          ..._slides.map((content) => _FeatureSlideLayout(
                content: content,
                animation: _motion,
                compact: compact,
                currentPage: _currentPage,
                totalPages: totalPages,
                onSkip: _finishToLogin,
                onBack: () => _goTo(_currentPage - 1),
                onNext: () {
                  if (_currentPage == totalPages - 1) {
                    _finishToLogin();
                  } else {
                    _goTo(_currentPage + 1);
                  }
                },
              )),
        ],
      ),
    );
  }
}

// ============================================================================
// COVER SLIDE (FIDÈLE À SCREEN 1 DE LA MAQUETTE FOURNIE)
// ============================================================================

class _WelcomeHeroCoverSlide extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onExplore;

  const _WelcomeHeroCoverSlide({
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image de carte / route verdoyante en plein écran
        Image.network(
          kAuthMapImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B4E0E), Color(0xFF2A7C13), Color(0xFF13380A)],
              ),
            ),
          ),
        ),

        // Dégradé sombre et teinté vert profond pour lisibilité parfaite
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                AppColors.primaireFonce.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0.0, 0.45, 0.95],
            ),
          ),
        ),

        // Contenu typographique et boutons (Screen 1 de l'image)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre supérieur et badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: AppColors.accent,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Campus Mobilité Verte',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onExplore,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explorer',
                            style: TextStyle(
                              color: AppColors.creme,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.creme,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Typographie percutante comme "The best app for your plants" dans la maquette
                const Text(
                  'The best app\nfor your journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Partagez vos trajets universitaires en Tunisie, économisez et faites de nouvelles rencontres.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),

                const Spacer(flex: 3),

                // Bouton translucide effet verre dépoli "Sign in" (comme dans l'image)
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.40),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: onSignIn,
                      child: const Center(
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Lien "Create an account" (comme dans l'image)
                Center(
                  child: GestureDetector(
                    onTap: onCreateAccount,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        'Create an account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SLIDES EXPLICATIVES DÉTAILLÉES (AVEC NOUVELLE PALETTE & ANIMATIONS)
// ============================================================================

class _FeatureSlideLayout extends StatelessWidget {
  final _IntroContent content;
  final Animation<double> animation;
  final bool compact;
  final int currentPage;
  final int totalPages;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _FeatureSlideLayout({
    required this.content,
    required this.animation,
    required this.compact,
    required this.currentPage,
    required this.totalPages,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final illustrationHeight = compact ? 280.0 : 330.0;

    return SafeArea(
      child: Column(
        children: [
          // Barre supérieure avec bouton retour et passer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.champFond,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primaire,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Covoiturage Étudiant',
                    style: TextStyle(
                      color: AppColors.primaire,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(60, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color: AppColors.texte2,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenu de la slide
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: illustrationHeight,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) => _Illustration(
                        kind: content.kind,
                        progress: animation.value,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 28),
                  Text(
                    content.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaire,
                      fontSize: 27,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      content.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.texte2,
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barre inférieure avec indicateurs pilules et bouton d'action
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
            child: Row(
              children: [
                // Indicateurs de page
                Row(
                  children: List.generate(totalPages, (index) {
                    final isSel = index == currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 6),
                      height: 7,
                      width: isSel ? 26 : 7,
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primaire : AppColors.champFond,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
                const Spacer(),

                // Bouton Suivant / Commencer (rgb(42, 124, 19))
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      elevation: 3,
                      shadowColor: AppColors.primaire.withValues(alpha: 0.30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentPage == totalPages - 1 ? 'Commencer' : 'Suivant',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _IllustrationKind { route, savings, trust }

class _IntroContent {
  const _IntroContent({
    required this.title,
    required this.description,
    required this.kind,
  });
  final String title;
  final String description;
  final _IllustrationKind kind;
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.kind, required this.progress});
  final _IllustrationKind kind;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: w,
            height: 270,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF3F8F1)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaire.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 24,
            child: _Glow(size: 110, color: AppColors.accent.withValues(alpha: 0.18)),
          ),
          if (kind == _IllustrationKind.route) _RouteArt(width: w, progress: progress),
          if (kind == _IllustrationKind.savings) _SavingsArt(width: w, progress: progress),
          if (kind == _IllustrationKind.trust) _TrustArt(width: w, progress: progress),
        ],
      );
    });
  }
}

class _RouteArt extends StatelessWidget {
  const _RouteArt({required this.width, required this.progress});
  final double width;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final shift = math.sin(progress * math.pi * 2) * 3;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _RoadPainter(progress: progress))),
      Positioned(
        left: width * 0.12,
        top: 60,
        child: const _Tag(icon: Icons.trip_origin_rounded, text: 'Départ', tint: AppColors.primaire),
      ),
      Positioned(
        right: width * 0.10,
        bottom: 50,
        child: const _Tag(icon: Icons.location_on_rounded, text: 'Faculté', tint: AppColors.accent),
      ),
      const Positioned(
        left: 20,
        bottom: 26,
        child: _InfoCard(icon: Icons.near_me_rounded, title: 'Trajet partagé', subtitle: '18 min • 12 km'),
      ),
      Positioned(
        left: width * (0.33 + progress * 0.22),
        top: 126 + shift,
        child: const _Car(),
      ),
      const Positioned(
        right: 22,
        top: 22,
        child: _FloatingIcon(icon: Icons.navigation_rounded, color: AppColors.primaire),
      ),
    ]);
  }
}

class _SavingsArt extends StatelessWidget {
  const _SavingsArt({required this.width, required this.progress});
  final double width;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(progress * math.pi * 2) * 4;
    return Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: CustomPaint(painter: _ConnectionsPainter(progress: progress))),
      Positioned(
        top: 24 + bob,
        left: 26,
        child: const _Avatar(color: AppColors.sable, initials: 'A'),
      ),
      Positioned(
        top: 24 - bob,
        right: 26,
        child: const _Avatar(color: AppColors.soutien, initials: 'M'),
      ),
      Positioned(top: 86, child: _FareSplitCard(progress: progress)),
      Positioned(
        bottom: 36 + bob,
        left: width * 0.18,
        child: const _Avatar(color: AppColors.creme, initials: 'S', size: 40),
      ),
      Positioned(
        bottom: 36 - bob,
        right: width * 0.18,
        child: const _Avatar(color: Color(0xFFD6ECCB), initials: 'Y', size: 40),
      ),
      const Positioned(bottom: 32, child: _Car()),
    ]);
  }
}

class _FareSplitCard extends StatelessWidget {
  const _FareSplitCard({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final reveal = Curves.easeOutCubic.transform(
      ((progress * 1.5) % 1).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: 0.82 + reveal * 0.18,
      child: Transform.translate(
        offset: Offset(0, (1 - reveal) * 6),
        child: Container(
          width: 216,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.champBordure),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaire.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.champFond,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: AppColors.primaire, size: 19),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Frais partagés',
                      style: TextStyle(
                        color: AppColors.texte,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    'Exemple',
                    style: TextStyle(
                      color: AppColors.texte2,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.bordure),
              const SizedBox(height: 9),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '3 covoitureurs',
                      style: TextStyle(color: AppColors.texte2, fontSize: 10.5),
                    ),
                  ),
                  Text(
                    '12 DT',
                    style: TextStyle(
                      color: AppColors.primaire,
                      fontSize: 21,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Padding(
                    padding: EdgeInsets.only(bottom: 1),
                    child: Text(
                      '/ pers.',
                      style: TextStyle(color: AppColors.texte2, fontSize: 9),
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

class _TrustArt extends StatelessWidget {
  const _TrustArt({required this.width, required this.progress});
  final double width;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.97 + (math.sin(progress * math.pi * 2) + 1) * 0.015;
    return Stack(alignment: Alignment.center, children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _ConnectionsPainter(progress: progress, trust: true),
        ),
      ),
      Transform.scale(
        scale: pulse,
        child: Container(
          width: 214,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaire.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  _Avatar(color: AppColors.sable, initials: 'N', size: 48),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nour Ben Ali',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.texte,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Conductrice vérifiée',
                          style: TextStyle(color: AppColors.texte2, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.star_rounded, color: Color(0xFFFFB648), size: 18),
                  Text(
                    '4.9',
                    style: TextStyle(
                      color: AppColors.texte,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.bordure),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.route_rounded, color: AppColors.primaire, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Ariana  →  ESPRIT',
                    style: TextStyle(
                      color: AppColors.texte,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: 28,
        right: width * 0.13,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.champFond,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            color: AppColors.primaire,
            size: 22,
          ),
        ),
      ),
      Positioned(
        bottom: 26,
        left: width * 0.10,
        child: const _FloatingIcon(
          icon: Icons.chat_bubble_rounded,
          color: AppColors.primaire,
        ),
      ),
      Positioned(
        bottom: 34,
        right: width * 0.10,
        child: const _FloatingIcon(
          icon: Icons.shield_rounded,
          color: AppColors.accent,
        ),
      ),
      const Positioned(
        top: 42,
        left: 20,
        child: _Tag(
          icon: Icons.favorite_rounded,
          text: 'Campus',
          tint: Color(0xFFE26161),
        ),
      ),
    ]);
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.67)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.32,
        size.width * 0.59,
        size.height * 0.83,
        size.width * 0.88,
        size.height * 0.37,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.champFond
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final metric = path.computeMetrics().first;
    final segment = metric.extractPath(0, metric.length * (0.25 + 0.55 * progress));
    canvas.drawPath(
      segment,
      Paint()
        ..color = AppColors.primaire
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConnectionsPainter extends CustomPainter {
  const _ConnectionsPainter({required this.progress, this.trust = false});
  final double progress;
  final bool trust;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (trust ? AppColors.accent : AppColors.primaire)
          .withValues(alpha: 0.22 + 0.12 * math.sin(progress * math.pi * 2).abs())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (trust) {
      final path = Path()
        ..moveTo(size.width * 0.18, size.height * 0.32)
        ..cubicTo(
          size.width * 0.34,
          size.height * 0.14,
          size.width * 0.52,
          size.height * 0.35,
          size.width * 0.77,
          size.height * 0.23,
        )
        ..moveTo(size.width * 0.18, size.height * 0.72)
        ..cubicTo(
          size.width * 0.30,
          size.height * 0.83,
          size.width * 0.66,
          size.height * 0.72,
          size.width * 0.83,
          size.height * 0.78,
        );
      canvas.drawPath(path, paint);
    } else {
      final center = Offset(size.width / 2, size.height / 2);
      for (final point in [
        Offset(size.width * 0.20, size.height * 0.24),
        Offset(size.width * 0.80, size.height * 0.24),
        Offset(size.width * 0.22, size.height * 0.78),
        Offset(size.width * 0.78, size.height * 0.78),
      ]) {
        canvas.drawLine(center, point, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trust != trust;
}

class _Car extends StatelessWidget {
  const _Car();

  @override
  Widget build(BuildContext context) => Container(
        width: 90,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaire, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaire.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 18,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.creme.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Positioned(bottom: -5, left: 13, child: _wheel()),
            Positioned(bottom: -5, right: 13, child: _wheel()),
            const Positioned(
              left: 5,
              child: Icon(Icons.circle, size: 7, color: Color(0xFFFFE39A)),
            ),
            const Positioned(
              right: 5,
              child: Icon(Icons.circle, size: 7, color: Color(0xFFFFE39A)),
            ),
          ],
        ),
      );

  Widget _wheel() => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.primaireFonce,
          border: Border.all(color: Colors.white, width: 2),
          shape: BoxShape.circle,
        ),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.initials, this.size = 46});
  final Color color;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaire.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.texte,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.35,
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.tint});
  final IconData icon;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaire.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.texte,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaire.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.champFond,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primaire, size: 17),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.texte2, fontSize: 9.5),
                ),
              ],
            ),
          ],
        ),
      );
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaire.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
}
