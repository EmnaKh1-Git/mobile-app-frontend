import 'package:flutter/material.dart';
import '../app/theme.dart';

class CurvedNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badge;

  const CurvedNavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badge = 0,
  });
}

class CurvedFloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedNavBarItem> items;
  final Color barColor;
  final Color activeColor;
  final Color inactiveColor;

  const CurvedFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.barColor = Colors.white,
    this.activeColor = AppColors.primaire,
    this.inactiveColor = AppColors.texte2,
  }) : assert(items.length >= 2, 'Il faut au moins 2 éléments dans la barre.');

  @override
  State<CurvedFloatingNavBar> createState() => _CurvedFloatingNavBarState();
}

class _CurvedFloatingNavBarState extends State<CurvedFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late double _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _positionAnimation = Tween<double>(
      begin: _currentPosition,
      end: _currentPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(covariant CurvedFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  void _animateTo(int targetIndex) {
    final start = _positionAnimation.value;
    final end = targetIndex.toDouble();
    _positionAnimation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    const navBarHeight = 84.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AnimatedBuilder(
        animation: _positionAnimation,
        builder: (context, _) {
          final position = _positionAnimation.value;

          return SizedBox(
            height: navBarHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tabWidth = width / count;
                final activeCx = (position + 0.5) * tabWidth;

                // Index le plus proche pour le label et l'icône active
                final activeIndex = position.round().clamp(0, count - 1);
                final activeItem = widget.items[activeIndex];

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Arrière-plan blanc avec bosse courbée organique
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CurvedNavBarPainter(
                          position: position,
                          count: count,
                          barColor: widget.barColor,
                        ),
                      ),
                    ),

                    // Bulle circulaire flottante sur la bosse (identique à la maquette)
                    Positioned(
                      left: activeCx - 26,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => widget.onTap(activeIndex),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.champFond,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.activeColor,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.activeColor.withValues(alpha: 0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              activeItem.activeIcon ?? activeItem.icon,
                              color: widget.activeColor,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Rangée des 5 onglets avec icônes et textes
                    Positioned.fill(
                      top: 18,
                      child: Row(
                        children: List.generate(count, (index) {
                          final item = widget.items[index];
                          // Distance à la position animée (0.0 = parfaitement actif)
                          final distance = (position - index).abs();
                          final isActive = distance < 0.45;

                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                widget.onTap(index);
                                _animateTo(index);
                              },
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Container(
                                height: double.infinity,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isActive) ...[
                                      // Onglet inactif : Icône + label
                                      Badge(
                                        isLabelVisible: item.badge > 0,
                                        label: Text('${item.badge}'),
                                        backgroundColor: AppColors.accent,
                                        child: Icon(
                                          item.icon,
                                          color: widget.inactiveColor.withValues(alpha: 0.8),
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: widget.inactiveColor.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ] else ...[
                                      // Onglet actif : Label en gras sous la bulle
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: widget.activeColor,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CurvedNavBarPainter extends CustomPainter {
  final double position;
  final int count;
  final Color barColor;

  const _CurvedNavBarPainter({
    required this.position,
    required this.count,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const baseTop = 20.0;
    const cornerRadius = 26.0;
    final tabWidth = w / count;

    // Centre de la bosse active
    final cx = (position + 0.5) * tabWidth;

    const bumpRadius = 36.0;
    const bumpPeakY = 3.0;

    final path = Path();

    // 1. Coin supérieur gauche
    path.moveTo(0, baseTop + cornerRadius);
    path.quadraticBezierTo(0, baseTop, cornerRadius, baseTop);

    // 2. Début de la bosse
    final bumpStartX = (cx - bumpRadius).clamp(cornerRadius, w - cornerRadius);
    final bumpEndX = (cx + bumpRadius).clamp(cornerRadius, w - cornerRadius);

    path.lineTo(bumpStartX, baseTop);

    // 3. Montée douce vers le sommet (cx, bumpPeakY)
    path.cubicTo(
      cx - bumpRadius * 0.55,
      baseTop,
      cx - bumpRadius * 0.40,
      bumpPeakY,
      cx,
      bumpPeakY,
    );

    // 4. Descente douce vers la ligne de base
    path.cubicTo(
      cx + bumpRadius * 0.40,
      bumpPeakY,
      cx + bumpRadius * 0.55,
      baseTop,
      bumpEndX,
      baseTop,
    );

    // 5. Coin supérieur droit
    path.lineTo(w - cornerRadius, baseTop);
    path.quadraticBezierTo(w, baseTop, w, baseTop + cornerRadius);

    // 6. Coin inférieur droit
    path.lineTo(w, h - cornerRadius);
    path.quadraticBezierTo(w, h, w - cornerRadius, h);

    // 7. Coin inférieur gauche
    path.lineTo(cornerRadius, h);
    path.quadraticBezierTo(0, h, 0, h - cornerRadius);
    path.close();

    // Ombre douce et élégante
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.12),
      14.0,
      false,
    );

    // Remplissage blanc
    final fillPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Ligne de bordure fine pour netteté
    final borderPaint = Paint()
      ..color = const Color(0xFFE5EDE3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNavBarPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.barColor != barColor;
}

