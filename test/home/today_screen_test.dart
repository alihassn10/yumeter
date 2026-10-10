import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/home/today_screen.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';

import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpToday(WidgetTester tester) async {
    // Tall enough that the meal list is built without scrolling.
    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    container = testContainer(await testPrefs(profile: sampleProfile));
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<MealEntry> logWrap() => container.read(mealLogProvider.notifier).add(
        type: MealType.lunch,
        name: 'Chicken wrap',
        calories: 540,
        proteinGrams: 38,
        carbGrams: 52,
        fatGrams: 18,
        loggedAt: logTimeFor(DateTime.now()),
      );

  testWidgets('an empty day invites a first log and shows the full budget',
      (tester) async {
    await pumpToday(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Log your first meal'), findsOneWidget);
    // Nothing eaten, so everything is left: the sample plan is 1574 kcal.
    expect(find.text('1,574'), findsOneWidget);
    expect(find.text('Eaten 0 · Goal 1,574'), findsOneWidget);
  });

  testWidgets('a logged meal appears and comes off the budget',
      (tester) async {
    await pumpToday(tester);
    await logWrap();
    await tester.pumpAndSettle();

    expect(find.text('Chicken wrap'), findsOneWidget);
    expect(find.text('Log your first meal'), findsNothing);
    expect(find.text('1,034'), findsOneWidget); // 1574 - 540
    expect(find.text('Eaten 540 · Goal 1,574'), findsOneWidget);
    expect(find.text('1 logged'), findsOneWidget);
  });

  testWidgets('a deleted meal can be brought back with undo',
      (tester) async {
    await pumpToday(tester);
    await logWrap();
    await tester.pumpAndSettle();

    await tester.drag(find.text('Chicken wrap'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Chicken wrap'), findsNothing);
    expect(container.read(mealLogProvider), isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Chicken wrap'), findsOneWidget);
    expect(container.read(mealLogProvider), hasLength(1));
  });

  testWidgets('the streak badge appears once something is logged',
      (tester) async {
    await pumpToday(tester);
    expect(find.text('1d'), findsNothing);

    await logWrap();
    await tester.pumpAndSettle();
    expect(find.text('1d'), findsOneWidget);
  });
}
