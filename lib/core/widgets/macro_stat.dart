import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// One column of the macro strip: gram count, label, and a slim progress track
/// tinted with that macro's accent.
class MacroStat extends StatelessWidget {
  const MacroStat({
    super.key,
    required this.label,
    required this.grams,
    required this.goalGrams,
    required this.color,
  });

  final String label;
  final int grams;
  final int goalGrams;
  final Color color;

  const MacroStat.protein({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Protein',
        color = AppColors.protein;

  const MacroStat.carbs({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Carbs',
        color = AppColors.carbs;

  const MacroStat.fat({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Fat',
        color = AppColors.fat;

  @override
  Widget build(BuildContext context) {
    // A zero goal would make the ratio undefined; show an empty track instead.
    final progress = goalGrams <= 0 ? 0.0 : (grams / goalGrams).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceNested,
        borderRadius: AppRadii.nestedShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${grams}g', style: AppTypography.metricSub),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                color: color,
                backgroundColor: AppColors.track,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
