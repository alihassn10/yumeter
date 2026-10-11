import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../home/widgets/meal_tile.dart';
import 'domain/meal_entry.dart';
import 'state/meal_log_controller.dart';

/// Every logged meal, newest day first, with each day's total.
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

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
    final meals = ref.watch(mealLogProvider);

    // Newest day first; within a day, newest meal first.
    final days = <DateTime, List<MealEntry>>{};
    for (final m in meals.reversed) {
      days.putIfAbsent(Dates.dateOnly(m.loggedAt), () => []).add(m);
    }
    final rows = <Object>[
      for (final MapEntry(key: day, value: entries) in days.entries) ...[
        (day, DayTotals.of(entries).calories),
        ...entries,
      ],
    ];

    return Scaffold(
      body: SafeArea(
        child: meals.isEmpty
            ? const _Empty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.lg,
                  AppSpacing.screenMargin,
                  AppSpacing.xl * 3,
                ),
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('Meals', style: AppTypography.headlineLarge),
                    );
                  }
                  return switch (rows[i - 1]) {
                    (final DateTime day, final int calories) => Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                Dates.friendlyDay(day),
                                style: AppTypography.labelLarge,
                              ),
                            ),
                            Text(
                              '${groupedNumber(calories)} kcal',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    final MealEntry entry => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: MealTile(
                          entry: entry,
                          onTap: () =>
                              context.push(AppRoutes.mealDetail(entry.id)),
                          onDelete: () => _delete(context, ref, entry),
                        ),
                      ),
                    _ => const SizedBox.shrink(),
                  };
                },
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No meals yet', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Everything you log shows up here, newest first.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
