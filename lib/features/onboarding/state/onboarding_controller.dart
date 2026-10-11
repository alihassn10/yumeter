import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/goal_calculator.dart';
import '../domain/onboarding_answers.dart';

/// The quiz, in order. The enum is the single source of truth for both the
/// page sequence and the "step n of m" counter.
enum OnboardingStep {
  sex,
  birthDate,
  measurements,
  activity,
  goal,
  targetWeight,
  pace,
  diet;

  int get number => index + 1;
  static int get total => OnboardingStep.values.length;
}

class OnboardingState {
  const OnboardingState({
    this.answers = const OnboardingAnswers(),
    this.stepIndex = 0,
  });

  final OnboardingAnswers answers;
  final int stepIndex;

  OnboardingStep get step => OnboardingStep.values[stepIndex];
  bool get isLastStep => stepIndex == OnboardingStep.values.length - 1;

  /// Whether the current step has enough input to move on. Steps with a
  /// pre-filled default are always satisfied.
  bool get canAdvance => switch (step) {
        OnboardingStep.sex => answers.sex != null,
        OnboardingStep.birthDate => answers.birthDate != null,
        OnboardingStep.measurements =>
          answers.heightCm != null && answers.weightKg != null,
        OnboardingStep.activity => answers.activityLevel != null,
        OnboardingStep.goal => answers.goal != null,
        // Maintaining has no target to pick, so the step self-satisfies.
        OnboardingStep.targetWeight => answers.goal == WeightGoal.maintain ||
            answers.targetWeightKg != null,
        OnboardingStep.pace => true,
        OnboardingStep.diet => true,
      };

  OnboardingState copyWith({OnboardingAnswers? answers, int? stepIndex}) =>
      OnboardingState(
        answers: answers ?? this.answers,
        stepIndex: stepIndex ?? this.stepIndex,
      );
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  /// Starts from saved answers, so a settings editor can reuse the quiz's
  /// steps on an existing profile.
  void load(OnboardingAnswers answers) =>
      state = OnboardingState(answers: answers);

  void _update(OnboardingAnswers answers) =>
      state = state.copyWith(answers: answers);

  void setSex(Sex value) => _update(state.answers.copyWith(sex: value));

  void setBirthDate(DateTime value) =>
      _update(state.answers.copyWith(birthDate: value));

  void setMeasurements({double? heightCm, double? weightKg}) => _update(
        state.answers.copyWith(heightCm: heightCm, weightKg: weightKg),
      );

  void setActivityLevel(ActivityLevel value) =>
      _update(state.answers.copyWith(activityLevel: value));

  void setDietType(DietType value) =>
      _update(state.answers.copyWith(dietType: value));

  void setUnits(UnitSystem value) =>
      _update(state.answers.copyWith(units: value));

  void setPace(double kgPerWeek) =>
      _update(state.answers.copyWith(paceKgPerWeek: kgPerWeek));

  void setTargetWeight(double kg) =>
      _update(state.answers.copyWith(targetWeightKg: kg));

  /// Picking a goal seeds a sensible target so the next step opens on a
  /// realistic number instead of an arbitrary one.
  void setGoal(WeightGoal value) {
    final current = state.answers.weightKg;
    final seeded = current == null
        ? null
        : switch (value) {
            WeightGoal.lose => current - 5,
            WeightGoal.gain => current + 5,
            WeightGoal.maintain => current,
          };
    _update(
      state.answers.copyWith(goal: value, targetWeightKg: seeded),
    );
  }

  /// Someone holding their weight has no target to pick, so that step is
  /// stepped over in both directions rather than shown empty.
  bool _shouldSkip(OnboardingStep step) =>
      step == OnboardingStep.targetWeight &&
      state.answers.goal == WeightGoal.maintain;

  /// Returns false at the last step so the caller can leave the flow instead.
  bool next() {
    if (!state.canAdvance) return false;
    var index = state.stepIndex;
    do {
      index++;
      if (index >= OnboardingStep.values.length) return false;
    } while (_shouldSkip(OnboardingStep.values[index]));
    state = state.copyWith(stepIndex: index);
    return true;
  }

  /// Returns false at the first step so the caller can leave the flow instead.
  bool back() {
    var index = state.stepIndex;
    do {
      index--;
      if (index < 0) return false;
    } while (_shouldSkip(OnboardingStep.values[index]));
    state = state.copyWith(stepIndex: index);
    return true;
  }

  NutritionPlan? get plan => GoalCalculator.tryCalculate(state.answers);
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
