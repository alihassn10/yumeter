import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/accent_badge.dart';
import '../../core/widgets/brand_mark.dart';
import '../log/log_sheet.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import '../plan/plan_providers.dart';
import 'widgets/calorie_summary_card.dart';
import 'widgets/meal_tile.dart';
import 'widgets/week_strip.dart';

/// The dashboard: the selected day's intake against the plan, and what was
/// eaten.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MealEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final log = ref.read(mealLogProvider.notifier);
    await log.remove(entry.id);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${entry.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => log.restore(entry),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activePlanProvider);
    final day = ref.watch(selectedDayProvider);
    final meals = ref.watch(dayMealsProvider);
    final totals = ref.watch(dayTotalsProvider);
    final streak = ref.watch(streakProvider);
    final loggedDays = ref.watch(loggedDaysProvider);
    final isToday = Dates.isSameDay(day, DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            AppSpacing.xl,
          ),
          children: [
            _Header(streak: streak),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Dates.friendlyDay(day),
                    style: AppTypography.headlineLarge,
                  ),
                ),
                if (!isToday)
                  TextButton(
                    onPressed: () => ref
                        .read(selectedDayProvider.notifier)
                        .select(DateTime.now()),
                    child: const Text('Back to today'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            WeekStrip(
              selected: day,
              loggedDays: loggedDays,
              onSelect: ref.read(selectedDayProvider.notifier).select,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (plan == null)
              const _MissingPlan()
            else
              CalorieSummaryCard(
                consumed: totals.calories,
                goal: plan.calories,
                proteinGrams: totals.proteinGrams,
                proteinGoal: plan.proteinGrams,
                carbsGrams: totals.carbGrams,
                carbsGoal: plan.carbGrams,
                fatGrams: totals.fatGrams,
                fatGoal: plan.fatGrams,
              ),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.pillShape,
                boxShadow: AppColors.glow(AppColors.calories),
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.scan),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Scan food'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text('Meals', style: AppTypography.headlineMedium),
                ),
                if (meals.isNotEmpty)
                  Text(
                    '${meals.length} logged',
                    style: AppTypography.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (meals.isEmpty)
              _EmptyDay(isToday: isToday)
            else
              for (final entry in meals) ...[
                MealTile(
                  entry: entry,
                  onDelete: () => _delete(context, ref, entry),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 36),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Yumeter', style: AppTypography.headlineSmall)),
        if (streak > 0)
          Semantics(
            label: '$streak day streak',
            excludeSemantics: true,
            child: AccentBadge(
              label: '${streak}d',
              icon: Icons.local_fire_department_rounded,
            ),
          ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.calories),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.calories,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isToday ? 'Log your first meal' : 'Nothing logged this day',
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isToday
                ? 'Snap a photo or add the calories by hand.'
                : 'You can still add a meal you forgot to log.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => showLogSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Log a meal'),
          ),
        ],
      ),
    );
  }
}

/// Shown if the dashboard is reached without a finished profile — a corrupt
/// save, or a route opened directly.
class _MissingPlan extends StatelessWidget {
  const _MissingPlan();

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
          Text(
            'Finish setting up to see your daily target.',
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.onboarding),
            child: const Text('Set up my plan'),
          ),
        ],
      ),
    );
  }
}
