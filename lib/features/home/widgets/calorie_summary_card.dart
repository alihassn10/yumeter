import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/accent_badge.dart';
import '../../../core/widgets/calorie_ring.dart';
import '../../../core/widgets/macro_stat.dart';

/// The home dashboard hero: remaining calories beside the gauge, with the
/// three-column macro strip seated underneath.
class CalorieSummaryCard extends StatelessWidget {
  const CalorieSummaryCard({
    super.key,
    required this.consumed,
    required this.goal,
    required this.proteinGrams,
    required this.proteinGoal,
    required this.carbsGrams,
    required this.carbsGoal,
    required this.fatGrams,
    required this.fatGoal,
    this.streakDays,
  });

  final int consumed;
  final int goal;
  final int proteinGrams;
  final int proteinGoal;
  final int carbsGrams;
  final int carbsGoal;
  final int fatGrams;
  final int fatGoal;
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final remaining = goal - consumed;
    final overBudget = remaining < 0;
    final progress = goal <= 0 ? 0.0 : consumed / goal;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remaining.abs().toString(),
                      style: AppTypography.metricHeadline.copyWith(
                        color: overBudget
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      overBudget ? 'Calories over' : 'Calories left',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              CalorieRing(
                progress: progress,
                size: 92,
                color: overBudget ? AppColors.error : AppColors.calories,
                child: streakDays == null
                    ? null
                    : AccentBadge(
                        label: '$streakDays',
                        icon: Icons.local_fire_department_rounded,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: MacroStat.protein(
                  grams: proteinGrams,
                  goalGrams: proteinGoal,
                ),
              ),
              Expanded(
                child: MacroStat.carbs(
                  grams: carbsGrams,
                  goalGrams: carbsGoal,
                ),
              ),
              Expanded(
                child: MacroStat.fat(grams: fatGrams, goalGrams: fatGoal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
