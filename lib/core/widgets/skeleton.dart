import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    required this.height,
    this.width = double.infinity,
    this.radius = AppRadius.sm,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations == true;
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (reduceMotion) return _block(base);
    return FadeTransition(
      opacity: Tween(begin: .55, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
      child: _block(base),
    );
  }

  Widget _block(Color color) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
}

class QuestionSkeleton extends StatelessWidget {
  const QuestionSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Carregando questão',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBlock(width: 96, height: 12),
              const SizedBox(height: AppSpacing.lg),
              const SkeletonBlock(height: 16),
              const SizedBox(height: AppSpacing.sm),
              const SkeletonBlock(height: 16),
              const SizedBox(height: AppSpacing.sm),
              const SkeletonBlock(width: 220, height: 16),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < 5; i++) ...[
                const SkeletonBlock(height: 58, radius: AppRadius.md),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      );
}

class ExamCardSkeleton extends StatelessWidget {
  const ExamCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: 110, height: 24),
              SizedBox(height: AppSpacing.lg),
              SkeletonBlock(height: 20),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(width: 210, height: 20),
              Spacer(),
              SkeletonBlock(height: 12),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(width: 150, height: 12),
            ],
          ),
        ),
      );
}
