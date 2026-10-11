import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/core/utils/dates.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/meal_detail_screen.dart';
import 'package:yumeter/features/meals/meals_screen.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';
import 'package:yumeter/features/scan/data/meal_photo_service.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 6000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        ...testOverrides(await testPrefs(profile: sampleProfile)),
        mealPhotoServiceProvider.overrideWithValue(FakeMealPhotoService([])),
      ],
    );
    addTearDown(container.dispose);

    final now = DateTime.now();
    final yesterday = Dates.addDays(now, -1);
    final log = container.read(mealLogProvider.notifier);
    await log.add(
      type: MealType.breakfast,
      name: 'Oats',
      calories: 300,
      loggedAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 8),
    );
    await log.add(
      type: MealType.lunch,
      name: 'Salmon bowl',
      calories: 515,
      proteinGrams: 38,
      loggedAt: DateTime(now.year, now.month, now.day, 0, 5),
      source: MealSource.photo,
      photoPath: 'user-a/m1.jpg',
    );

    final router = GoRouter(
      initialLocation: AppRoutes.meals,
      routes: [
        GoRoute(
          path: AppRoutes.meals,
          builder: (_, _) => const MealsScreen(),
        ),
        GoRoute(
          path: AppRoutes.mealDetailPattern,
          builder: (_, state) =>
              MealDetailScreen(mealId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups meals by day, newest first, with day totals',
      (tester) async {
    await pump(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('515 kcal'), findsOneWidget);
    expect(find.text('300 kcal'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Salmon bowl')).dy,
      lessThan(tester.getTopLeft(find.text('Oats')).dy),
    );
  });

  testWidgets('opening a photo meal shows its details and photo slot',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Salmon bowl'));
    await tester.pumpAndSettle();

    expect(find.text('Estimated from a photo'), findsOneWidget);
    expect(find.text('38g'), findsOneWidget);
    // Tests are offline, so the photo falls back to its placeholder.
    expect(find.text('Photo unavailable offline'), findsOneWidget);
  });

  testWidgets('editing a meal saves the change', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Oats'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'kcal'), '350');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final oats = container
        .read(mealLogProvider)
        .firstWhere((m) => m.name == 'Oats');
    expect(oats.calories, 350);
    expect(find.text('350 kcal'), findsOneWidget);
  });

  testWidgets('deleting from the detail screen asks first, then removes it',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Oats'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this meal?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(mealLogProvider).map((m) => m.name), [
      'Salmon bowl',
    ]);
    expect(find.text('Deleted Oats'), findsOneWidget);
  });
}
