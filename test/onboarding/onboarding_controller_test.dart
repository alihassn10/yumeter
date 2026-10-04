import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';
import 'package:yumeter/features/onboarding/state/onboarding_controller.dart';

void main() {
  late ProviderContainer container;
  late OnboardingController controller;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    controller = container.read(onboardingControllerProvider.notifier);
  });

  OnboardingState state() => container.read(onboardingControllerProvider);

  /// Answers every step up to and including [stop].
  void answerThrough(OnboardingStep stop) {
    for (final step in OnboardingStep.values) {
      switch (step) {
        case OnboardingStep.sex:
          controller.setSex(Sex.female);
        case OnboardingStep.birthDate:
          controller.setBirthDate(DateTime(1996, 3, 12));
        case OnboardingStep.measurements:
          controller.setMeasurements(heightCm: 168, weightKg: 64);
        case OnboardingStep.activity:
          controller.setActivityLevel(ActivityLevel.moderate);
        case OnboardingStep.goal:
          controller.setGoal(WeightGoal.lose);
        case OnboardingStep.targetWeight:
          controller.setTargetWeight(58);
        case OnboardingStep.pace:
          controller.setPace(0.5);
        case OnboardingStep.diet:
          controller.setDietType(DietType.highProtein);
      }
      if (step == stop) return;
    }
  }

  group('advancing', () {
    test('will not advance before the step is answered', () {
      expect(state().canAdvance, isFalse);
      expect(controller.next(), isFalse);
      expect(state().stepIndex, 0);
    });

    test('advances once the step is answered', () {
      controller.setSex(Sex.male);
      expect(state().canAdvance, isTrue);
      expect(controller.next(), isTrue);
      expect(state().step, OnboardingStep.birthDate);
    });

    test('reports false at the last step so the caller can leave', () {
      answerThrough(OnboardingStep.diet);
      while (!state().isLastStep) {
        expect(controller.next(), isTrue);
      }
      expect(controller.next(), isFalse);
      expect(state().step, OnboardingStep.diet);
    });
  });

  group('going back', () {
    test('reports false at the first step so the caller can leave', () {
      expect(controller.back(), isFalse);
      expect(state().stepIndex, 0);
    });

    test('returns to the previous step', () {
      controller.setSex(Sex.male);
      controller.next();
      expect(controller.back(), isTrue);
      expect(state().step, OnboardingStep.sex);
    });
  });

  group('maintaining weight', () {
    void advanceToGoal() {
      answerThrough(OnboardingStep.goal);
      while (state().step != OnboardingStep.goal) {
        controller.next();
      }
    }

    test('skips the target weight step going forward', () {
      advanceToGoal();
      controller.setGoal(WeightGoal.maintain);
      controller.next();
      expect(state().step, OnboardingStep.pace);
    });

    test('skips it going back too', () {
      advanceToGoal();
      controller.setGoal(WeightGoal.maintain);
      controller.next();
      controller.back();
      expect(state().step, OnboardingStep.goal);
    });

    test('still shows the step when a target is wanted', () {
      advanceToGoal();
      controller.setGoal(WeightGoal.lose);
      controller.next();
      expect(state().step, OnboardingStep.targetWeight);
    });

    test('the skipped step does not block advancing', () {
      advanceToGoal();
      controller.setGoal(WeightGoal.maintain);
      expect(state().canAdvance, isTrue);
    });
  });

  group('picking a goal', () {
    test('seeds a target below current weight when losing', () {
      controller.setMeasurements(heightCm: 170, weightKg: 80);
      controller.setGoal(WeightGoal.lose);
      expect(state().answers.targetWeightKg, 75);
    });

    test('seeds a target above current weight when gaining', () {
      controller.setMeasurements(heightCm: 170, weightKg: 80);
      controller.setGoal(WeightGoal.gain);
      expect(state().answers.targetWeightKg, 85);
    });

    test('leaves the target unset when weight is not known yet', () {
      controller.setGoal(WeightGoal.lose);
      expect(state().answers.targetWeightKg, isNull);
    });
  });

  group('plan', () {
    test('is null until the quiz has what the formula needs', () {
      expect(controller.plan, isNull);
    });

    test('is produced once the quiz is answered', () {
      answerThrough(OnboardingStep.diet);
      final plan = controller.plan;
      expect(plan, isNotNull);
      expect(plan!.calories, greaterThan(0));
      expect(plan.proteinGrams, greaterThan(0));
    });
  });
}
