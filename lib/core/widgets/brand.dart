import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 40, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _BrandPainter()));
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(size: compact ? 34 : 40),
        const SizedBox(width: 10),
        if (!compact) const Text('Prova Social', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5)),
      ]);
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, Paint()..color = AppColors.brand);
    final page = Paint()..color = Colors.white;
    final left = Path()..moveTo(s * .20, s * .26)..quadraticBezierTo(s * .37, s * .25, s * .48, s * .38)..lineTo(s * .48, s * .67)..quadraticBezierTo(s * .35, s * .56, s * .20, s * .57)..close();
    final right = Path()..moveTo(s * .80, s * .26)..quadraticBezierTo(s * .63, s * .25, s * .52, s * .38)..lineTo(s * .52, s * .67)..quadraticBezierTo(s * .65, s * .56, s * .80, s * .57)..close();
    canvas.drawPath(left, page);
    canvas.drawPath(right, page);
    final layers = Paint()..color = AppColors.mint..style = PaintingStyle.stroke..strokeWidth = s * .055..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final y in [.72, .82]) {
      canvas.drawPath(Path()..moveTo(s * .23, s * y)..lineTo(s * .50, s * (y + .08))..lineTo(s * .77, s * y), layers);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
