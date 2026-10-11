import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/core/utils/dates.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';
import 'package:yumeter/features/progress/progress_screen.dart';
import 'package:yumeter/features/progress/state/weight_log_controller.dart';
import 'package:yumeter/features/progress/widgets/progress_charts.dart';

import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {bool withData = true}) async {
    tester.view
      ..physicalSize = const Size(1170, 7000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = testContainer(await testPrefs(profile: sampleProfile));
    addTearDown(container.dispose);

    if (withData) {
      final now = DateTime.now();
      final log = container.read(mealLogProvider.notifier);
      for (var i = 0; i < 3; i++) {
        final d = Dates.addDays(now, -i);
        await log.add(
          type: MealType.lunch,
          name: 'Lunch $i',
          calories: 1500,
          proteinGrams: 90,
          carbGrams: 150,
          fatGrams: 50,
          loggedAt: DateTime(d.year, d.month, d.day, 12),
        );
      }
      final weights = container.read(weightLogProvider.notifier);
      await weights.log(Dates.addDays(now, -5), 65.0);
      await weights.log(now, 64.4);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the charts and stats from logged data', (tester) async {
    await pump(tester);

    expect(find.byType(CalorieChart), findsOneWidget);
    expect(find.byType(WeightChart), findsOneWidget);
    expect(find.byType(MacroSplitBar), findsOneWidget);
    expect(find.text('3 of 7 days logged'), findsOneWidget);
    expect(find.text('1,500 kcal'), findsOneWidget);
    expect(find.text('64.4 kg'), findsWidgets);
    expect(find.text('−0.6 kg this week'), findsOneWidget);
  });

  testWidgets('switching range recomputes the summary', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 30 days logged'), findsOneWidget);
  });

  testWidgets('with nothing logged it explains instead of drawing zeros',
      (tester) async {
    await pump(tester, withData: false);

    expect(find.text('0 of 7 days logged'), findsOneWidget);
    expect(find.byType(WeightChart), findsNothing);
    expect(
      find.textContaining('No weigh-ins in this period yet'),
      findsOneWidget,
    );
    expect(find.textContaining('No macros logged'), findsOneWidget);
  });

  testWidgets("the weight sheet logs today's weight", (tester) async {
    await pump(tester, withData: false);

    await tester.tap(find.text("Log today's weight"));
    await tester.pumpAndSettle();
    expect(find.text('Save weight'), findsOneWidget);
    await tester.tap(find.text('Save weight'));
    await tester.pumpAndSettle();

    final logged = container.read(weightLogProvider).single;
    expect(logged.day, Dates.dateOnly(DateTime.now()));
    // Opens at the onboarding weight when there is no weigh-in yet.
    expect(logged.weightKg, sampleProfile.weightKg);
  });
}
