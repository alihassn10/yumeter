import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/log/quick_add_screen.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';

import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;

  /// Opens quick add on top of a stub page, the way the log sheet does, so
  /// closing it has somewhere to return to.
  Future<void> openQuickAdd(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    container = testContainer(await testPrefs(profile: sampleProfile));
    addTearDown(container.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/quick-add'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/quick-add',
          builder: (_, _) =>
              const QuickAddScreen(initialType: MealType.dinner),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String keys) async {
    for (final key in keys.split('')) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
  }

  ElevatedButton logButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('cannot log until calories are entered', (tester) async {
    await openQuickAdd(tester);
    expect(find.text('Enter calories'), findsOneWidget);
    expect(logButton(tester).onPressed, isNull);
  });

  testWidgets('logs calories and macros to the chosen meal', (tester) async {
    await openQuickAdd(tester);

    await press(tester, '450');
    expect(find.text('Log 450 kcal to Dinner'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Protein'));
    await tester.pump();
    await press(tester, '30');
    expect(find.text('30g'), findsOneWidget);

    await tester.tap(find.text('Log 450 kcal to Dinner'));
    await tester.pumpAndSettle();

    final entry = container.read(mealLogProvider).single;
    expect(entry.calories, 450);
    expect(entry.proteinGrams, 30);
    expect(entry.carbGrams, 0);
    expect(entry.type, MealType.dinner);
    expect(entry.name, 'Quick add');
    // Back on the page it was opened from, with confirmation.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Logged 450 kcal to Dinner'), findsOneWidget);
  });

  testWidgets('the increment chips add to the calorie figure', (tester) async {
    await openQuickAdd(tester);
    await tester.tap(find.text('+250'));
    await tester.pump();
    await tester.tap(find.text('+100'));
    await tester.pump();
    expect(find.text('Log 350 kcal to Dinner'), findsOneWidget);
  });

  testWidgets('backspace removes the last digit and C clears the field',
      (tester) async {
    await openQuickAdd(tester);
    await press(tester, '1234');
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();
    expect(find.text('Log 123 kcal to Dinner'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear'));
    await tester.pump();
    expect(find.text('Enter calories'), findsOneWidget);
  });

  testWidgets('caps calories at four digits', (tester) async {
    await openQuickAdd(tester);
    await press(tester, '99999');
    expect(find.text('Log 9,999 kcal to Dinner'), findsOneWidget);
  });

  testWidgets('flags macros that disagree with the calories and can adopt them',
      (tester) async {
    await openQuickAdd(tester);
    await press(tester, '100');
    await tester.tap(find.bySemanticsLabel('Protein'));
    await tester.pump();
    await press(tester, '50'); // 50 g protein is 200 kcal, double the entry.

    expect(find.text('Macros add up to 200 kcal'), findsOneWidget);
    await tester.tap(find.text('Use that'));
    await tester.pump();
    expect(find.text('Log 200 kcal to Dinner'), findsOneWidget);
    expect(find.text('Macros add up to 200 kcal'), findsNothing);
  });

  // Found on the device: typing protein first raised "Macros add up to
  // 120 kcal" and offered to overwrite the 450 already entered.
  testWidgets('does not nag while macros are still being typed',
      (tester) async {
    await openQuickAdd(tester);
    await press(tester, '450');
    await tester.tap(find.bySemanticsLabel('Protein'));
    await tester.pump();
    await press(tester, '30');

    expect(find.textContaining('Macros add up to'), findsNothing);
    expect(find.text('Use that'), findsNothing);
  });

  testWidgets('flags a shortfall once all three macros are in',
      (tester) async {
    await openQuickAdd(tester);
    await press(tester, '800');
    for (final (label, grams) in const [
      ('Protein', '20'),
      ('Carbs', '30'),
      ('Fat', '10'),
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      await press(tester, grams);
    }

    // 20*4 + 30*4 + 10*9 = 290 kcal against 800 entered.
    expect(find.text('Macros add up to 290 kcal'), findsOneWidget);
  });

  testWidgets('switching meal type updates the button', (tester) async {
    await openQuickAdd(tester);
    await press(tester, '200');
    await tester.tap(find.text('Snack'));
    await tester.pump();
    expect(find.text('Log 200 kcal to Snack'), findsOneWidget);
  });
}
