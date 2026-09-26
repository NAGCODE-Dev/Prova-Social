import 'package:flutter/material.dart';

import '../../domain/models/exam.dart';
import '../theme/app_theme.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    required this.sourceType,
    this.compact = false,
    super.key,
  });

  final ExamSourceType sourceType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (sourceType) {
      ExamSourceType.official => ('Fonte oficial', Icons.verified_outlined),
      ExamSourceType.community => (
        'Enviado pela comunidade',
        Icons.people_outline_rounded,
      ),
      ExamSourceType.unverified => (
        'Fonte não verificada',
        Icons.help_outline_rounded,
      ),
    };
    final shortLabel = switch (sourceType) {
      ExamSourceType.official => 'Oficial',
      ExamSourceType.community => 'Comunidade',
      ExamSourceType.unverified => 'Não verificada',
    };
    final color = sourceType == ExamSourceType.official
        ? AppColors.brandHover
        : AppColors.muted;
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sourceType == ExamSourceType.official
              ? AppColors.brandSoft
              : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 3 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                compact ? shortLabel : label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
