import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/profile_store.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../onboarding/state/onboarding_controller.dart';

/// The answers the app should act on.
///
/// The quiz wins while it holds a complete set — that is the path straight out
/// of onboarding, before anything is read back from disk. Otherwise the stored
/// profile is used, which is the case on every later launch.
final activeAnswersProvider = Provider<OnboardingAnswers?>((ref) {
  final quiz = ref.watch(onboardingControllerProvider).answers;
  if (GoalCalculator.tryCalculate(quiz) != null) return quiz;
  return ref.watch(storedProfileProvider);
});

/// Daily targets derived from [activeAnswersProvider], or null when there is
/// no complete profile yet.
final activePlanProvider = Provider<NutritionPlan?>((ref) {
  final answers = ref.watch(activeAnswersProvider);
  if (answers == null) return null;
  return GoalCalculator.tryCalculate(answers);
});
