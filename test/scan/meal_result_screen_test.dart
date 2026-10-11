import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yumeter/core/router/app_routes.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';
import 'package:yumeter/features/scan/data/meal_photo_service.dart';
import 'package:yumeter/features/scan/domain/meal_draft.dart';
import 'package:yumeter/features/scan/domain/picked_photo.dart';
import 'package:yumeter/features/scan/meal_result_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

/// A 1×1 PNG, so Image.memory has something real to decode.
final _pixel = PickedPhoto(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=',
  ),
  extension: 'jpg',
);

const _bowl = MealDraft(
  name: 'Salmon bowl',
  items: [
    DraftItem(
      name: 'Rice',
      portion: '1 cup',
      calories: 205,
      proteinGrams: 4,
      carbGrams: 45,
      fatGrams: 1,
    ),
    DraftItem(
      name: 'Salmon',
      portion: '150 g',
      calories: 310,
      proteinGrams: 34,
      fatGrams: 18,
    ),
  ],
);

void main() {
  late ProviderContainer container;
  late FakeMealPhotoService photos;

  Future<void> pumpResult(WidgetTester tester, List<Object> results) async {
    // A tall phone, so the whole review fits without scrolling.
    tester.view
      ..physicalSize = const Size(1170, 6000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    photos = FakeMealPhotoService(results);
    container = ProviderContainer(
      overrides: [
        ...testOverrides(
          await testPrefs(profile: sampleProfile),
          auth: FakeAuthRepository(user: testUser),
        ),
        mealPhotoServiceProvider.overrideWithValue(photos),
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
          path: AppRoutes.quickAdd,
          builder: (_, _) => const Scaffold(body: Text('quick add')),
        ),
        GoRoute(
          path: AppRoutes.foodSearch,
          builder: (_, _) => const Scaffold(body: Text('food search')),
        ),
        GoRoute(
          path: AppRoutes.mealResult,
          builder: (_, state) =>
              MealResultScreen(photo: state.extra! as PickedPhoto),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    router.push(AppRoutes.mealResult, extra: _pixel);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the estimate with every food listed', (tester) async {
    await pumpResult(tester, [_bowl]);

    expect(find.text('Salmon bowl'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Salmon'), findsOneWidget);
    expect(find.text('Log 515 kcal'), findsOneWidget);
    expect(
      find.text('Estimated from your photo. Tap any food to adjust it.'),
      findsOneWidget,
    );
  });

  testWidgets('logging saves a photo meal under the uploaded photo',
      (tester) async {
    await pumpResult(tester, [_bowl]);

    await tester.tap(find.text('Log 515 kcal'));
    await tester.pumpAndSettle();

    final meal = container.read(mealLogProvider).single;
    expect(meal.name, 'Salmon bowl');
    expect(meal.calories, 515);
    expect(meal.proteinGrams, 38);
    expect(meal.source, MealSource.photo);
    expect(meal.photoPath, photos.uploads.single);
    expect(photos.uploads.single, '${testUser.id}/${meal.id}.jpg');
    expect(photos.removed, isEmpty, reason: 'the photo belongs to the meal');
    expect(find.text('today'), findsOneWidget);
  });

  testWidgets('removing a food updates the total before logging',
      (tester) async {
    await pumpResult(tester, [_bowl]);

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from meal'));
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsNothing);
    expect(find.text('Log 310 kcal'), findsOneWidget);
  });

  testWidgets('a double portion doubles the food', (tester) async {
    await pumpResult(tester, [_bowl]);

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2×'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('2 × 1 cup  ·  P 8g · C 90g · F 2g'), findsOneWidget);
    expect(find.text('Log 720 kcal'), findsOneWidget);
  });

  testWidgets('a photo with no food offers a retake and keeps nothing',
      (tester) async {
    await pumpResult(tester, [
      const AnalysisFailure(AnalysisFailureKind.notFood),
    ]);

    expect(find.text('No food found'), findsOneWidget);
    await tester.tap(find.text('Take another photo'));
    await tester.pumpAndSettle();

    expect(container.read(mealLogProvider), isEmpty);
    expect(photos.removed, photos.uploads, reason: 'unused photo deleted');
  });

  testWidgets('a retry after a busy server reuses the uploaded photo',
      (tester) async {
    await pumpResult(tester, [
      const AnalysisFailure(AnalysisFailureKind.rateLimited),
      _bowl,
    ]);

    expect(find.text('Busy right now'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Salmon bowl'), findsOneWidget);
    expect(photos.uploads, hasLength(1));
  });

  testWidgets('the daily limit points to logging that needs no photo',
      (tester) async {
    await pumpResult(tester, [
      const AnalysisFailure(AnalysisFailureKind.dailyLimit),
    ]);

    expect(find.text('Daily photo limit reached'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.text('Search food'));
    await tester.pumpAndSettle();

    expect(find.text('food search'), findsOneWidget);
    expect(photos.removed, photos.uploads, reason: 'unused photo deleted');
  });

  testWidgets('offline points to typing the meal in', (tester) async {
    await pumpResult(tester, [
      const AnalysisFailure(AnalysisFailureKind.offline),
    ]);

    expect(find.text('You are offline'), findsOneWidget);
    await tester.tap(find.text('Type it in instead'));
    await tester.pumpAndSettle();

    expect(find.text('quick add'), findsOneWidget);
  });
}
