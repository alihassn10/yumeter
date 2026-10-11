import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/food/data/food_repository.dart';
import 'package:yumeter/features/food/domain/food_product.dart';
import 'package:yumeter/features/food/food_product_screen.dart';
import 'package:yumeter/features/food/food_search_screen.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

const _yogurt = FoodProduct(
  code: '111',
  name: 'Greek Yogurt',
  brand: 'Chobani',
  servingGrams: 150,
  servingLabel: '1 pot (150 g)',
  kcalPer100g: 60,
  proteinPer100g: 10,
  carbPer100g: 4,
  fatPer100g: 0,
);

const _oats = FoodProduct(
  code: '222',
  name: 'Rolled Oats',
  kcalPer100g: 380,
  proteinPer100g: 13,
  carbPer100g: 60,
  fatPer100g: 7,
);

void main() {
  late ProviderContainer container;
  late FakeFoodRepository food;

  Future<void> pump(WidgetTester tester, {String? at, Object? extra}) async {
    tester.view
      ..physicalSize = const Size(1170, 6000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    food = FakeFoodRepository([_yogurt, _oats]);
    container = ProviderContainer(
      overrides: [
        ...testOverrides(await testPrefs(profile: sampleProfile)),
        foodRepositoryProvider.overrideWithValue(food),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        GoRoute(
          path: AppRoutes.today,
          builder: (_, _) => const Scaffold(body: Text('today')),
        ),
        GoRoute(
          path: AppRoutes.foodSearch,
          builder: (_, _) =>
              const FoodSearchScreen(mealType: MealType.breakfast),
        ),
        GoRoute(
          path: AppRoutes.foodProduct,
          builder: (_, state) =>
              FoodProductScreen(args: state.extra! as FoodProductArgs),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    router.push(at ?? AppRoutes.foodSearch, extra: extra);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  group('FoodSearchScreen', () {
    testWidgets('searches on submit, not while typing', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'yog');
      await tester.pump();
      expect(food.queries, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(food.queries, ['yog']);
      expect(find.text('Greek Yogurt'), findsOneWidget);
      expect(find.textContaining('per serving'), findsOneWidget);
      expect(find.textContaining('Open Food Facts'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pump(tester);
      await search(tester, 'zzz');
      expect(find.textContaining('No matches'), findsOneWidget);
    });

    testWidgets('a failed search explains and offers a retry', (tester) async {
      await pump(tester);
      food.failure = FoodLookupFailure.busy;
      await search(tester, 'oats');

      expect(find.textContaining('busy'), findsOneWidget);
      food.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Rolled Oats'), findsOneWidget);
    });

    testWidgets('opens a result to log it', (tester) async {
      await pump(tester);
      await search(tester, 'oats');
      await tester.tap(find.text('Rolled Oats'));
      await tester.pumpAndSettle();

      expect(find.text('Log 380 kcal to Breakfast'), findsOneWidget);
    });
  });

  group('FoodProductScreen', () {
    testWidgets('starts at one serving when the label gives one',
        (tester) async {
      await pump(
        tester,
        at: AppRoutes.foodProduct,
        extra: const FoodProductArgs(
          product: _yogurt,
          source: MealSource.barcode,
        ),
      );

      expect(find.text('1 × 1 pot (150 g)'), findsOneWidget);
      expect(find.text('90 kcal'), findsOneWidget);
      // 90 of the sample profile's 1,574 kcal.
      expect(find.textContaining('6% of your 1,574 kcal'), findsOneWidget);
    });

    testWidgets('more servings scale everything', (tester) async {
      await pump(
        tester,
        at: AppRoutes.foodProduct,
        extra: const FoodProductArgs(
          product: _yogurt,
          source: MealSource.barcode,
        ),
      );

      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(find.text('1.5 × 1 pot (150 g)'), findsOneWidget);
      expect(find.text('135 kcal'), findsOneWidget);
    });

    testWidgets('logging saves a barcode meal with its amount',
        (tester) async {
      await pump(
        tester,
        at: AppRoutes.foodProduct,
        extra: const FoodProductArgs(
          product: _yogurt,
          source: MealSource.barcode,
          mealType: MealType.snack,
        ),
      );

      await tester.tap(find.text('Log 90 kcal to Snack'));
      await tester.pumpAndSettle();

      final meal = container.read(mealLogProvider).single;
      expect(meal.name, 'Chobani Greek Yogurt (150 g)');
      expect(meal.calories, 90);
      expect(meal.proteinGrams, 15);
      expect(meal.source, MealSource.barcode);
      expect(meal.type, MealType.snack);
      expect(find.text('today'), findsOneWidget);
    });

    testWidgets('without a serving size it works in grams', (tester) async {
      await pump(
        tester,
        at: AppRoutes.foodProduct,
        extra: const FoodProductArgs(product: _oats, source: MealSource.search),
      );

      expect(find.text('100 g'), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      await tester.tap(find.byTooltip('Less'));
      await tester.pump();
      expect(find.text('95 g'), findsOneWidget);
      expect(find.text('361 kcal'), findsOneWidget);
    });
  });
}
