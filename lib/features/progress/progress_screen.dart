import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/profile_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../meals/state/meal_log_controller.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../plan/plan_providers.dart';
import 'domain/progress_stats.dart';
import 'domain/weight_entry.dart';
import 'state/weight_log_controller.dart';
import 'weight_log_sheet.dart';
import 'widgets/progress_charts.dart';

/// The window the Progress tab is showing. Kept while the app runs, so the
/// choice survives switching tabs.
class SelectedRange extends Notifier<ProgressRange> {
  @override
  ProgressRange build() => ProgressRange.week;

  void select(ProgressRange range) => state = range;
}

final progressRangeProvider = NotifierProvider<SelectedRange, ProgressRange>(
  SelectedRange.new,
);

/// Intake and weight over time, from what the user has logged.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(progressRangeProvider);
    final meals = ref.watch(mealLogProvider);
    final weights = ref.watch(weightLogProvider);
    final plan = ref.watch(activePlanProvider);
    final profile = ref.watch(storedProfileProvider);
    final streak = ref.watch(streakProvider);

    final today = DateTime.now();
    final summary = summarize(meals, range, today: today);
    final imperial = profile?.units == UnitSystem.imperial;
    final unit = imperial ? 'lb' : 'kg';
    double display(double kg) => imperial ? Units.kgToLb(kg) : kg;

    final start = rangeStart(range, today: today, meals: meals, weights: weights);
    final rangeWeights = weightsSince(weights, start);
    final currentKg = weights.lastOrNull?.weightKg ?? profile?.weightKg;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.xl * 3,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Progress', style: AppTypography.headlineLarge),
                ),
                if (streak > 0) _StreakChip(days: streak),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<ProgressRange>(
              segments: [
                for (final r in ProgressRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {range},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(progressRangeProvider.notifier).select(s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Card(
              title: 'Calories',
              subtitle: switch (range) {
                ProgressRange.week || ProgressRange.month =>
                  'Daily intake against your target',
                _ => 'Average per logged day',
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 200,
                    child: CalorieChart(
                      bars: summary.bars,
                      target: plan?.calories,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${summary.loggedDays} of ${summary.daysInRange} days '
                    'logged',
                    style: AppTypography.bodySmall,
                  ),
                  if (plan != null)
                    Text(
                      'Dashed line: your ${groupedNumber(plan.calories)} kcal '
                      'target',
                      style: AppTypography.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // A fixed height, not an aspect ratio, so a two-line detail
              // fits on the narrowest phones.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: 128,
              ),
              children: [
                _Stat(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Daily average',
                  value: summary.averageCalories == null
                      ? '—'
                      : groupedNumber(summary.averageCalories!),
                  unit: 'kcal',
                  detail: _vsTarget(summary.averageCalories, plan?.calories),
                ),
                _Stat(
                  icon: Icons.bolt_rounded,
                  label: 'Protein',
                  value: summary.averageProteinGrams == null
                      ? '—'
                      : '${summary.averageProteinGrams}',
                  unit: 'g a day',
                  detail: summary.averageProteinGrams == null ||
                          plan == null
                      ? null
                      : '${(summary.averageProteinGrams! / plan.proteinGrams * 100).round()}% of your '
                          '${plan.proteinGrams}g target',
                ),
                _Stat(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Weight',
                  value: currentKg == null
                      ? '—'
                      : display(currentKg).toStringAsFixed(1),
                  unit: unit,
                  detail: rangeWeights.length < 2
                      ? null
                      : _change(
                          display(rangeWeights.last.weightKg) -
                              display(rangeWeights.first.weightKg),
                          unit,
                          range,
                        ),
                ),
                _Stat(
                  icon: Icons.event_available_rounded,
                  label: 'Streak',
                  value: '$streak',
                  unit: streak == 1 ? 'day' : 'days',
                  detail: 'Days in a row with a meal logged',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Card(
              title: 'Weight',
              subtitle: profile?.targetWeightKg == null
                  ? 'Your weigh-ins'
                  : 'Your weigh-ins and goal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rangeWeights.length >= 2)
                    SizedBox(
                      height: 180,
                      child: WeightChart(
                        points: [
                          for (final w in rangeWeights)
                            (w.day, display(w.weightKg)),
                        ],
                        unit: unit,
                        goal: profile?.goal == WeightGoal.maintain ||
                                profile?.targetWeightKg == null
                            ? null
                            : display(profile!.targetWeightKg!),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        rangeWeights.isEmpty
                            ? 'No weigh-ins in this period yet. Log your '
                                'weight to start your trend.'
                            : 'One weigh-in so far. Log another to see your '
                                'trend.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: () => showWeightLogSheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Log today's weight"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Card(
              title: 'Macros',
              subtitle: 'Share of calories from each macro',
              child: summary.macros == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        'No macros logged in this period. Photo meals and '
                        'quick adds with macros show up here.',
                        style: AppTypography.bodyMedium,
                      ),
                    )
                  : MacroSplitBar(split: summary.macros!),
            ),
            if (weights.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Recent weigh-ins', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              for (final w in weights.reversed.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _WeighInTile(
                    entry: w,
                    text: '${display(w.weightKg).toStringAsFixed(1)} $unit',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _vsTarget(int? average, int? target) {
    if (average == null || target == null) return null;
    final diff = average - target;
    if (diff == 0) return 'On your target';
    return '${groupedNumber(diff.abs())} ${diff > 0 ? 'over' : 'under'} '
        'your ${groupedNumber(target)} target';
  }

  static String _change(double delta, String unit, ProgressRange range) {
    final sign = delta > 0.05 ? '+' : delta < -0.05 ? '−' : '±';
    final period = switch (range) {
      ProgressRange.week => 'this week',
      ProgressRange.month => 'this month',
      ProgressRange.quarter => 'in 3 months',
      ProgressRange.all => 'overall',
    };
    return '$sign${delta.abs().toStringAsFixed(1)} $unit $period';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          if (subtitle case final s?) ...[
            const SizedBox(height: 2),
            Text(s, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.nestedShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text.rich(
            TextSpan(
              text: value,
              style: AppTypography.metricSub,
              children: [
                TextSpan(text: ' $unit', style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (detail case final d?)
            Text(
              d,
              style: AppTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.calories),
        borderRadius: AppRadii.pillShape,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: AppColors.calories,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$days ${days == 1 ? 'day' : 'days'}',
            style: AppTypography.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _WeighInTile extends ConsumerWidget {
  const _WeighInTile({required this.entry, required this.text});

  final WeightEntry entry;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('weight-${entry.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        final log = ref.read(weightLogProvider.notifier);
        log.remove(entry);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted the weigh-in for '
                  '${Dates.friendlyDay(entry.day)}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => log.log(entry.day, entry.weightKg),
              ),
            ),
          );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.error),
          borderRadius: AppRadii.nestedShape,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.nestedShape),
        child: ListTile(
          leading: const Icon(Icons.monitor_weight_outlined),
          title: Text(text),
          subtitle: Text(
            Dates.friendlyDay(entry.day),
            style: AppTypography.bodySmall,
          ),
        ),
      ),
    );
  }
}
