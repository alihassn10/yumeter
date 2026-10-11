import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import 'state/onboarding_controller.dart';
import 'steps/onboarding_steps.dart';
import 'widgets/onboarding_scaffold.dart';

/// Hosts the quiz. Every step shares one scaffold and swaps only its content,
/// so the progress header and button stay put while the question slides.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final (eyebrow, title, subtitle, content) = onboardingStepContent(state.step);

    return OnboardingScaffold(
      step: state.step.number,
      totalSteps: OnboardingStep.total,
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      continueLabel: state.isLastStep ? 'Build my plan' : 'Continue',
      footnote: 'You can change any of this later in settings.',
      onBack: () {
        // At the first question there is nothing to step back to.
        if (!controller.back()) context.go(AppRoutes.welcome);
      },
      onContinue: state.canAdvance
          ? () {
              if (!controller.next()) context.go(AppRoutes.creatingPlan);
            }
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(state.step), child: content),
      ),
    );
  }

}

/// The eyebrow, question, hint and input for each step. Shared with the
/// settings editors, so changing an answer later looks exactly like giving it.
(String?, String, String?, Widget) onboardingStepContent(OnboardingStep step) =>
      switch (step) {
        OnboardingStep.sex => (
            'About you',
            'Which best describes you?',
            'This sets the baseline your calorie target is built from.',
            const SexStep(),
          ),
        OnboardingStep.birthDate => (
            'About you',
            'How old are you?',
            'Age changes how much energy your body burns at rest.',
            const BirthDateStep(),
          ),
        OnboardingStep.measurements => (
            'About you',
            'Your height and weight',
            'Drag each ruler to set your numbers.',
            const MeasurementsStep(),
          ),
        OnboardingStep.activity => (
            'Your week',
            'How active are you?',
            'Count workouts and physically demanding work.',
            const ActivityStep(),
          ),
        OnboardingStep.goal => (
            'Your goal',
            'What do you want to do?',
            null,
            const GoalStep(),
          ),
        OnboardingStep.targetWeight => (
            'Your goal',
            'What weight are you aiming for?',
            null,
            const TargetWeightStep(),
          ),
        OnboardingStep.pace => (
            'Your goal',
            'How fast do you want to get there?',
            'A slower pace is easier to stick with.',
            const PaceStep(),
          ),
        OnboardingStep.diet => (
            'Your food',
            'How do you like to eat?',
            'This decides how your calories split across macros.',
            const DietStep(),
          ),
      };
