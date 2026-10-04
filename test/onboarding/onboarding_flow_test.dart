import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/onboarding/onboarding_screen.dart';
import 'package:yumeter/features/onboarding/state/onboarding_controller.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ElevatedButton continueButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('the first step blocks continuing until an option is picked',
      (tester) async {
    await pumpOnboarding(tester);
    expect(continueButton(tester).onPressed, isNull);

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(continueButton(tester).onPressed, isNotNull);
  });

  // A step that opens on a default must record that default, or it reads as
  // answered while Continue stays dead.
  testWidgets('the age step is answerable without touching the wheel',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('How old are you?'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('the measurements step is answerable without dragging',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your height and weight'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('walking the whole quiz produces a plan', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.dark,
              home: const OnboardingScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Answer the choice steps by label; the rest carry usable defaults.
    Future<void> advance({String? pick}) async {
      if (pick != null) {
        await tester.tap(find.text(pick));
        await tester.pumpAndSettle();
      }
      final label = find.text('Continue').evaluate().isNotEmpty
          ? 'Continue'
          : 'Build my plan';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await advance(pick: 'Female');
    await advance();
    await advance();
    await advance(pick: 'Moderately active');
    await advance(pick: 'Lose weight');
    await advance();
    await advance();

    final controller =
        container.read(onboardingControllerProvider.notifier);
    expect(controller.state.step, OnboardingStep.diet);

    final plan = controller.plan;
    expect(plan, isNotNull);
    expect(plan!.calories, greaterThan(0));
    expect(
      container.read(onboardingControllerProvider).answers.sex,
      Sex.female,
    );
  });
}
