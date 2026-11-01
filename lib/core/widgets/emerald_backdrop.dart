import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmeraldBackdrop extends StatelessWidget {
  const EmeraldBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: EmeraldColors.background),
      Positioned(
        top: -260,
        right: -210,
        width: 640,
        height: 640,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                EmeraldColors.primaryDark.withValues(alpha: .36),
                EmeraldColors.primaryDark.withValues(alpha: .12),
                Colors.transparent,
              ],
              stops: const [0, .48, 1],
            ),
          ),
        ),
      ),
      const Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _EmeraldArcsPainter()),
        ),
      ),
      child,
    ],
  );
}

class StudySurface extends StatelessWidget {
  const StudySurface({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlighted
              ? EmeraldColors.surfaceElevated
              : EmeraldColors.surface.withValues(alpha: .96),
          EmeraldColors.backgroundSecondary.withValues(alpha: .96),
        ],
      ),
      border: Border.all(
        color: highlighted
            ? EmeraldColors.borderHighlight.withValues(alpha: .8)
            : EmeraldColors.border,
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .16),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        if (highlighted)
          BoxShadow(
            color: EmeraldColors.primaryGlow.withValues(alpha: .07),
            blurRadius: 26,
            spreadRadius: 1,
          ),
      ],
    ),
    child: child,
  );
}

class _EmeraldArcsPainter extends CustomPainter {
  const _EmeraldArcsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 1.05, size.height * .18);
    final shortestSide = size.shortestSide;
    for (final (scale, opacity) in [(1.05, .13), (1.3, .09), (1.58, .06)]) {
      final rect = Rect.fromCircle(
        center: center,
        radius: shortestSide * scale,
      );
      canvas.drawArc(
        rect,
        1.9,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = EmeraldColors.primary.withValues(alpha: opacity),
      );
    }
    final glowRect = Rect.fromCircle(
      center: Offset(size.width * .03, size.height * .47),
      radius: shortestSide * .55,
    );
    canvas.drawCircle(
      glowRect.center,
      glowRect.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            EmeraldColors.primaryDark.withValues(alpha: .11),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
  }

  @override
  bool shouldRepaint(covariant _EmeraldArcsPainter oldDelegate) => false;
}
