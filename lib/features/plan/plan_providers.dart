import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/profile_store.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../onboarding/state/onboarding_controller.dart';

/// The answers the app should act on.
///
/// The saved profile wins: every save refreshes it, so it is always the
/// committed version. The quiz only counts when nothing is saved yet. Letting
/// a complete quiz win would leak an edit the user cancelled in settings,
/// since those editors reuse the quiz's state.
final activeAnswersProvider = Provider<OnboardingAnswers?>((ref) {
  final stored = ref.watch(storedProfileProvider);
  if (stored != null) return stored;
  final quiz = ref.watch(onboardingControllerProvider).answers;
  return GoalCalculator.tryCalculate(quiz) != null ? quiz : null;
});

/// Daily targets derived from [activeAnswersProvider], or null when there is
/// no complete profile yet.
final activePlanProvider = Provider<NutritionPlan?>((ref) {
  final answers = ref.watch(activeAnswersProvider);
  if (answers == null) return null;
  return GoalCalculator.tryCalculate(answers);
});
