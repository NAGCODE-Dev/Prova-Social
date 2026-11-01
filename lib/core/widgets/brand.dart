import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Prova Social',
    image: true,
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .09),
      decoration: BoxDecoration(
        color: EmeraldColors.backgroundSecondary,
        border: Border.all(color: EmeraldColors.borderHighlight),
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [
          BoxShadow(
            color: EmeraldColors.primaryGlow.withValues(alpha: .08),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .2),
        child: Image.asset(
          'assets/branding/app_icon.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: compact ? 42 : 50),
      const SizedBox(width: 10),
      if (!compact)
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
            children: [
              const TextSpan(
                text: 'Prova ',
                style: TextStyle(color: EmeraldColors.textPrimary),
              ),
              TextSpan(
                text: 'Social',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
    ],
  );
}
