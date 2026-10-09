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
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (reduced) {
      controller.stop();
    } else {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (_reducedMotion) return _block(base);
    return FadeTransition(
      opacity: Tween(
        begin: .55,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          const SkeletonBlock(width: 44, height: 56, radius: AppRadius.sm),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 140, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBlock(width: 150, height: 11),
                SizedBox(height: AppSpacing.xs),
                SkeletonBlock(width: 120, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const SkeletonBlock(width: 40, height: 40, radius: 20),
        ],
      ),
    ),
  );
}

class ExamListSkeleton extends StatelessWidget {
  const ExamListSkeleton({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Carregando provas',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            const ExamCardSkeleton(),
          ],
        ],
      ),
    ),
  );
}
