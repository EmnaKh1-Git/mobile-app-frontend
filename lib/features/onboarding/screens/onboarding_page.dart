import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../features/user/screens/login_page.dart';

const _navy = Color(0xFF101828);
const _blue = Color(0xFF3563FF);
const _cyan = Color(0xFF42D9FF);
const _pale = Color(0xFFF3F6FB);

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
      duration: const Duration(milliseconds: 1050),
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
        const Duration(milliseconds: 1750),
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
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, _, _) => const AppIntroPage(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
      backgroundColor: _navy,
      body: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final reveal = Curves.easeOutCubic.transform(_entrance.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101828), Color(0xFF142D61), Color(0xFF244FC7)],
                    stops: [0, .58, 1],
                  ),
                ),
              ),
              Positioned(
                top: -125,
                right: -110,
                child: _Glow(size: 360, color: _cyan.withValues(alpha: .13)),
              ),
              Positioned(
                bottom: -190,
                left: -140,
                child: _Glow(size: 430, color: _blue.withValues(alpha: .22)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashRoutePainter(progress: reveal),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: reveal,
                      child: Transform.translate(
                        offset: Offset(0, (1 - reveal) * 18),
                        child: Transform.scale(
                          scale: .88 + .12 * reveal,
                          child: Column(
                            children: [
                              Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyan.withValues(alpha: .12),
                                      blurRadius: 36,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const CustomPaint(
                                  painter: _SplashLogoPainter(),
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Covoiturage Étudiant',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.7,
                                ),
                              ),
                              const SizedBox(height: 11),
                              Text(
                                'Votre trajet, notre destination.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .72),
                                  fontSize: 15,
                                  letterSpacing: .15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _cyan,
                              backgroundColor: Colors.white.withValues(alpha: .14),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'En route ensemble',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .58),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
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
      ..moveTo(size.width * .22, size.height * .72)
      ..cubicTo(
        size.width * .32,
        size.height * .48,
        size.width * .63,
        size.height * .76,
        size.width * .76,
        size.height * .30,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withValues(alpha: .46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * .22, size.height * .72),
      7,
      Paint()..color = _cyan,
    );
    canvas.drawCircle(
      Offset(size.width * .76, size.height * .30),
      7,
      Paint()..color = _cyan,
    );
    final car = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .51, size.height * .51),
        width: size.width * .34,
        height: size.height * .19,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(car, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .43, size.height * .43, size.width * .17, size.height * .07),
        const Radius.circular(5),
      ),
      Paint()..color = _blue,
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
    final path = Path()
      ..moveTo(size.width * .02, size.height * .77)
      ..cubicTo(
        size.width * .30,
        size.height * .61,
        size.width * .65,
        size.height * .91,
        size.width * 1.05,
        size.height * .62,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = _cyan.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashRoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class AppIntroPage extends StatefulWidget {
  const AppIntroPage({super.key});

  @override
  State<AppIntroPage> createState() => _AppIntroPageState();
}

class _AppIntroPageState extends State<AppIntroPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _motion;
  int _currentPage = 0;

  static const _pages = [
    _IntroContent(
      title: 'Le trajet devient plus simple',
      description: 'Trouvez facilement des conducteurs et des passagers qui partagent votre destination.',
      kind: _IllustrationKind.route,
    ),
    _IntroContent(
      title: 'Voyagez mieux, dépensez moins',
      description: 'Partagez les frais du trajet, économisez sur vos déplacements et profitez d’une solution plus intelligente.',
      kind: _IllustrationKind.savings,
    ),
    _IntroContent(
      title: 'La confiance à chaque trajet',
      description: 'Consultez les informations des conducteurs, échangez avec les passagers et organisez vos trajets en toute sérénité.',
      kind: _IllustrationKind.trust,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= _pages.length) return;
    _pageController.animateToPage(page, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
  }

  void _finish() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      backgroundColor: _pale,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        tooltip: 'Retour',
                        onPressed: () => _goTo(_currentPage - 1),
                        style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(46, 46)),
                        icon: const Icon(Icons.arrow_back_rounded, color: _navy),
                      )
                    else
                      const SizedBox(width: 46),
                    const Spacer(),
                    Text('Covoiturage Étudiant', style: TextStyle(color: _navy.withValues(alpha: .72), fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    SizedBox(
                      width: 64,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(minimumSize: const Size(64, 46), padding: EdgeInsets.zero),
                        child: const Text('Passer', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) => _IntroSlide(
                  content: _pages[index],
                  animation: _motion,
                  compact: compact,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 7),
                      height: 8,
                      width: index == _currentPage ? 28 : 8,
                      decoration: BoxDecoration(color: index == _currentPage ? _blue : const Color(0xFFD4DCEB), borderRadius: BorderRadius.circular(10)),
                    )),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _currentPage == _pages.length - 1 ? _finish : () => _goTo(_currentPage + 1),
                      style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 25), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 4, shadowColor: _blue.withValues(alpha: .25)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_currentPage == _pages.length - 1 ? 'Commencer' : 'Suivant', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(width: 10), const Icon(Icons.arrow_forward_rounded, size: 19)]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({required this.content, required this.animation, required this.compact});

  final _IntroContent content;
  final Animation<double> animation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final illustrationHeight = compact ? 300.0 : 365.0;
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: illustrationHeight, child: AnimatedBuilder(animation: animation, builder: (context, _) => _Illustration(kind: content.kind, progress: animation.value))),
            SizedBox(height: compact ? 12 : 24),
            Text(content.title, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontSize: 28, height: 1.16, fontWeight: FontWeight.w800, letterSpacing: -.6)),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Text(content.description, textAlign: TextAlign.center, style: TextStyle(color: _navy.withValues(alpha: .62), fontSize: 15.5, height: 1.55)),
            ),
          ],
        ),
      );
    });
  }
}

enum _IllustrationKind { route, savings, trust }

class _IntroContent {
  const _IntroContent({required this.title, required this.description, required this.kind});
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
          Container(width: w, height: 280, decoration: BoxDecoration(borderRadius: BorderRadius.circular(42), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEAF0FF)]), boxShadow: [BoxShadow(color: const Color(0xFF20345E).withValues(alpha: .08), blurRadius: 35, offset: const Offset(0, 18))])),
          Positioned(top: 20, right: 24, child: _Glow(size: 120, color: _cyan.withValues(alpha: .18))),
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
      Positioned(left: width * .15, top: 68, child: _Tag(icon: Icons.trip_origin_rounded, text: 'Départ', tint: _blue)),
      Positioned(right: width * .10, bottom: 54, child: _Tag(icon: Icons.location_on_rounded, text: 'Destination', tint: const Color(0xFF13B89A))),
      Positioned(left: 21, bottom: 34, child: _InfoCard(icon: Icons.near_me_rounded, title: 'Trajet partagé', subtitle: '18 min • 12 km')),
      Positioned(left: width * (.35 + progress * .2), top: 132 + shift, child: const _Car()),
      Positioned(right: 22, top: 25, child: _FloatingIcon(icon: Icons.navigation_rounded, color: _blue)),
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
      Positioned(top: 26 + bob, left: 27, child: const _Avatar(color: Color(0xFFFFC27A), initials: 'A')),
      Positioned(top: 26 - bob, right: 27, child: const _Avatar(color: Color(0xFF78C9D5), initials: 'M')),
      Positioned(top: 88, child: _FareSplitCard(progress: progress)),
      Positioned(bottom: 38 + bob, left: width * .20, child: const _Avatar(color: Color(0xFFB7A1F7), initials: 'S', size: 42)),
      Positioned(bottom: 38 - bob, right: width * .20, child: const _Avatar(color: Color(0xFFFF9B9B), initials: 'Y', size: 42)),
      const Positioned(bottom: 37, child: _Car()),
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
      opacity: .82 + reveal * .18,
      child: Transform.translate(
        offset: Offset(0, (1 - reveal) * 6),
        child: Container(
          width: 210,
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDF1F8)),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: .11),
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: _blue, size: 18),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Frais partagés',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    'Exemple',
                    style: TextStyle(
                      color: Color(0xFF8992A2),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEEF1F6)),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      '3 voyageurs',
                      style: TextStyle(color: Color(0xFF727D90), fontSize: 10),
                    ),
                  ),
                  const Text(
                    '12 DT',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 1),
                    child: Text('/ pers.', style: TextStyle(color: Color(0xFF727D90), fontSize: 9)),
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
    final pulse = .97 + (math.sin(progress * math.pi * 2) + 1) * .015;
    return Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: CustomPaint(painter: _ConnectionsPainter(progress: progress, trust: true))),
      Transform.scale(scale: pulse, child: Container(width: 208, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: _navy.withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 14))]), child: Column(mainAxisSize: MainAxisSize.min, children: [const Row(children: [ _Avatar(color: Color(0xFF78C9D5), initials: 'N', size: 52), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Nour Ben Ali', style: TextStyle(fontWeight: FontWeight.w800, color: _navy, fontSize: 14)), SizedBox(height: 4), Text('Conductrice', style: TextStyle(color: Color(0xFF7A8496), fontSize: 12))])), Icon(Icons.star_rounded, color: Color(0xFFFFB648), size: 18), Text('4.9', style: TextStyle(color: _navy, fontWeight: FontWeight.w700, fontSize: 12))]), const SizedBox(height: 14), Container(height: 1, color: const Color(0xFFEEF1F6)), const SizedBox(height: 12), const Row(children: [Icon(Icons.route_rounded, color: _blue, size: 17), SizedBox(width: 8), Text('Tunis  →  Sousse', style: TextStyle(color: _navy, fontSize: 12, fontWeight: FontWeight.w600))])]))),
      Positioned(top: 31, right: width * .14, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE5FAF4), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.verified_user_rounded, color: Color(0xFF13B89A), size: 24))),
      Positioned(bottom: 29, left: width * .10, child: const _FloatingIcon(icon: Icons.chat_bubble_rounded, color: _blue)),
      Positioned(bottom: 39, right: width * .10, child: const _FloatingIcon(icon: Icons.shield_rounded, color: Color(0xFF13B89A))),
      Positioned(top: 45, left: 22, child: const _Tag(icon: Icons.favorite_rounded, text: 'Communauté', tint: Color(0xFFFF7C8B))),
      Positioned(bottom: 13, left: width * .33, child: Text('Éléments illustratifs', style: TextStyle(color: _navy.withValues(alpha: .45), fontSize: 10, fontWeight: FontWeight.w500))),
    ]);
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(size.width * .12, size.height * .67)..cubicTo(size.width * .23, size.height * .32, size.width * .59, size.height * .83, size.width * .88, size.height * .37);
    canvas.drawPath(path, Paint()..color = const Color(0xFFDDE5F5)..style = PaintingStyle.stroke..strokeWidth = 35..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    final metric = path.computeMetrics().first;
    final segment = metric.extractPath(0, metric.length * (.25 + .55 * progress));
    canvas.drawPath(segment, Paint()..color = _blue..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => oldDelegate.progress != progress;
}

class _ConnectionsPainter extends CustomPainter {
  const _ConnectionsPainter({required this.progress, this.trust = false});
  final double progress;
  final bool trust;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = (trust ? const Color(0xFF13B89A) : _blue).withValues(alpha: .22 + .12 * math.sin(progress * math.pi * 2).abs())..style = PaintingStyle.stroke..strokeWidth = 2;
    if (trust) {
      final path = Path()..moveTo(size.width * .18, size.height * .32)..cubicTo(size.width * .34, size.height * .14, size.width * .52, size.height * .35, size.width * .77, size.height * .23)..moveTo(size.width * .18, size.height * .72)..cubicTo(size.width * .3, size.height * .83, size.width * .66, size.height * .72, size.width * .83, size.height * .78);
      canvas.drawPath(path, paint);
    } else {
      final center = Offset(size.width / 2, size.height / 2);
      for (final point in [Offset(size.width * .20, size.height * .24), Offset(size.width * .80, size.height * .24), Offset(size.width * .22, size.height * .78), Offset(size.width * .78, size.height * .78)]) {
        canvas.drawLine(center, point, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.trust != trust;
}

class _Car extends StatelessWidget {
  const _Car();
  @override
  Widget build(BuildContext context) => Container(width: 92, height: 49, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, Color(0xFF6386FF)]), borderRadius: BorderRadius.circular(19), boxShadow: [BoxShadow(color: _blue.withValues(alpha: .25), blurRadius: 15, offset: const Offset(0, 8))]), child: Stack(alignment: Alignment.center, children: [Container(width: 44, height: 18, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: const Color(0xFFBEEBFF), borderRadius: BorderRadius.circular(10))), Positioned(bottom: -5, left: 13, child: _wheel()), Positioned(bottom: -5, right: 13, child: _wheel()), const Positioned(left: 5, child: Icon(Icons.circle, size: 7, color: Color(0xFFFFE39A))), const Positioned(right: 5, child: Icon(Icons.circle, size: 7, color: Color(0xFFFFE39A)))]));
  Widget _wheel() => Container(width: 14, height: 14, decoration: BoxDecoration(color: _navy, border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle));
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.initials, this.size = 48});
  final Color color;
  final String initials;
  final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: _navy.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 5))]), child: Text(initials, style: TextStyle(color: _navy.withValues(alpha: .75), fontWeight: FontWeight.w800, fontSize: size * .34)));
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.tint});
  final IconData icon;
  final String text;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _navy.withValues(alpha: .08), blurRadius: 14, offset: const Offset(0, 6))]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: tint), const SizedBox(width: 6), Text(text, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.w700))]));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _navy.withValues(alpha: .10), blurRadius: 18, offset: const Offset(0, 8))]), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: _blue, size: 17)), const SizedBox(width: 9), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF7B8495), fontSize: 9.5))]) ]));
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: _navy.withValues(alpha: .10), blurRadius: 15, offset: const Offset(0, 6))]), child: Icon(icon, color: color, size: 20));
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])));
}

