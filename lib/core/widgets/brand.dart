import 'package:flutter/material.dart';


class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 40, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Prova Social',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .23),
          child: Image.asset(
            'assets/branding/app_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
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
