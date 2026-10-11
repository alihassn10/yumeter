import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/storage/profile_store.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/onboarding/domain/goal_calculator.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';
import 'package:yumeter/features/plan/plan_providers.dart';
import 'package:yumeter/features/settings/settings_screen.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 6000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  int planCalories() => container.read(activePlanProvider)!.calories;

  testWidgets('shows the account and the profile the plan is built from',
      (tester) async {
    await pump(tester);

    expect(find.text(testUser.email!), findsOneWidget);
    expect(find.text('1,574 kcal'), findsOneWidget);
    expect(find.text('Lose weight · 0.5 kg a week'), findsOneWidget);
    expect(find.text('60.0 kg'), findsOneWidget);
    expect(find.text('5.0 kg to go'), findsOneWidget);
    expect(find.text('165 cm'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Moderately active'), findsOneWidget);
    // The disclaimer closes the list, below the fold.
    await tester.scrollUntilVisible(
      find.textContaining('not give medical advice'),
      300,
    );
    expect(find.textContaining('not give medical advice'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
  });

  testWidgets('the calorie target explains how it was worked out',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Daily calorie target'));
    await tester.pumpAndSettle();

    expect(find.text('How your target is worked out'), findsOneWidget);
    expect(find.text('Energy at rest'), findsOneWidget);
    expect(find.text('With your activity'), findsOneWidget);
    // 0.5 kg a week of fat is 550 kcal a day.
    expect(find.text('−550 kcal'), findsOneWidget);
  });

  testWidgets('changing the goal saves it and recalculates the plan',
      (tester) async {
    await pump(tester);
    final before = planCalories();

    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintain weight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(container.read(storedProfileProvider)!.goal, WeightGoal.maintain);
    expect(planCalories(), before + 550);
    // Maintaining has no target weight to show.
    expect(find.text('Target weight'), findsNothing);
  });

  testWidgets('backing out of an edit leaves the plan untouched',
      (tester) async {
    await pump(tester);
    final before = planCalories();

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra active'));
    await tester.pumpAndSettle();
    // Dismiss the sheet without saving.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(
      container.read(storedProfileProvider)!.activityLevel,
      ActivityLevel.moderate,
    );
    expect(planCalories(), before);
  });

  testWidgets('switching units changes how measurements read', (tester) async {
    await pump(tester);

    await tester.tap(find.text('lb, ft'));
    await tester.pumpAndSettle();

    expect(
      container.read(storedProfileProvider)!.units,
      UnitSystem.imperial,
    );
    final (feet, inches) = Units.cmToFeetInches(165);
    expect(find.text('$feet′ $inches″'), findsOneWidget);
    // The stored values stay metric; only the display changes.
    expect(container.read(storedProfileProvider)!.heightCm, 165);
  });
}
