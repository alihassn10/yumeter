import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_badge.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import 'plan_providers.dart';

/// The payoff screen: the daily target the quiz produced, what it is made of,
/// and what it is not (a measurement, or medical advice).
class PlanRevealScreen extends ConsumerWidget {
  const PlanRevealScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(activeAnswersProvider);
    final plan = ref.watch(activePlanProvider);

    // Reachable if the route is opened directly without a finished quiz.
    if (answers == null || plan == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We need a few answers first.',
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.onboarding),
                  child: const Text('Start over'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final metric = answers.units == UnitSystem.metric;
    final goalDate = GoalCalculator.projectedGoalDate(
      currentWeightKg: answers.weightKg!,
      targetWeightKg: answers.targetWeightKg,
      paceKgPerWeek: answers.paceKgPerWeek,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const Center(
                      child: AccentBadge(
                        label: 'Your plan is ready',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        tinted: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DailyTarget(calories: plan.calories),
                    if (plan.clampedToFloor) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _Notice(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.carbs,
                        text:
                            'We raised your target to keep it above a safe '
                            'minimum, so you will move a little slower than '
                            'the pace you picked.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _MacroBreakdown(plan: plan),
                    const SizedBox(height: AppSpacing.lg),
                    _HowWeGotThere(plan: plan),
                    if (goalDate != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _GoalProjection(
                        targetWeightKg: answers.targetWeightKg!,
                        date: goalDate,
                        metric: metric,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _Notice(
                      icon: Icons.health_and_safety_outlined,
                      color: AppColors.textSecondary,
                      text:
                          'These are estimates from a standard formula, not a '
                          'measurement, and not medical advice. Adjust as you '
                          'see how your weight actually responds, and talk to '
                          'a doctor or dietitian before big changes.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.lg,
              ),
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.paywall),
                child: const Text('Start tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTarget extends StatelessWidget {
  const _DailyTarget({required this.calories});

  final int calories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        children: [
          Text('Daily calorie target', style: AppTypography.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              text: '$calories',
              style: AppTypography.displayLarge
                  .copyWith(color: AppColors.calories),
              children: [
                TextSpan(
                  text: '  kcal',
                  style: AppTypography.headlineSmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBreakdown extends StatelessWidget {
  const _MacroBreakdown({required this.plan});

  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Protein', plan.proteinGrams, 4, AppColors.protein),
      ('Carbs', plan.carbGrams, 4, AppColors.carbs),
      ('Fat', plan.fatGrams, 9, AppColors.fat),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily macros', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          for (final (i, (label, grams, kcalPerGram, color))
              in rows.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _MacroRow(
              label: label,
              grams: grams,
              // Share of the day's energy this macro carries.
              share: plan.calories == 0
                  ? 0
                  : (grams * kcalPerGram) / plan.calories,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.grams,
    required this.share,
    required this.color,
  });

  final String label;
  final int grams;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppTypography.bodyLarge)),
            Text(
              '${grams}g',
              style: AppTypography.metricSub.copyWith(color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(share * 100).round()}%',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: share.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.track,
            ),
          ),
        ),
      ],
    );
  }
}

class _HowWeGotThere extends StatelessWidget {
  const _HowWeGotThere({required this.plan});

  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final shift = plan.calories - plan.tdee;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How we got there', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          _Line(
            label: 'Burned at rest',
            value: '${plan.bmr} kcal',
          ),
          _Line(
            label: 'With your activity',
            value: '${plan.tdee} kcal',
          ),
          _Line(
            label: shift == 0
                ? 'No adjustment'
                : shift < 0
                    ? 'Deficit for your goal'
                    : 'Surplus for your goal',
            value: shift == 0 ? '—' : '${shift > 0 ? '+' : ''}$shift kcal',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyMedium)),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              color: highlight ? AppColors.calories : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProjection extends StatelessWidget {
  const _GoalProjection({
    required this.targetWeightKg,
    required this.date,
    required this.metric,
  });

  final double targetWeightKg;
  final DateTime date;
  final bool metric;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final weight = metric
        ? '${targetWeightKg.toStringAsFixed(1)} kg'
        : '${Units.kgToLb(targetWeightKg).toStringAsFixed(1)} lb';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: AppColors.calories),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('On this pace', style: AppTypography.bodySmall),
                const SizedBox(height: 2),
                Text(
                  '$weight around '
                  '${_months[date.month - 1]} ${date.day}, ${date.year}',
                  style: AppTypography.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceNested,
        borderRadius: AppRadii.nestedShape,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }
}
