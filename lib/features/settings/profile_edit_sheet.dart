import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/profile_store.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../auth/data/account_sync.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/state/onboarding_controller.dart';
import '../progress/state/weight_log_controller.dart';

/// Opens an editor for some of the profile's answers, using the onboarding
/// steps themselves so a change looks exactly like the original question.
///
/// The quiz state is seeded from the saved profile and reset afterwards, so
/// an edit the user backs out of never reaches the plan.
Future<void> showProfileEditor(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<OnboardingStep> steps,
}) async {
  final profile = ref.read(storedProfileProvider);
  if (profile == null) return;
  final quiz = ref.read(onboardingControllerProvider.notifier)..load(profile);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ProfileEditSheet(title: title, steps: steps),
  );
  if (context.mounted) {
    ref.invalidate(onboardingControllerProvider);
  } else {
    quiz.load(const OnboardingAnswers());
  }
}

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key, required this.title, required this.steps});

  final String title;
  final List<OnboardingStep> steps;

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  bool _saving = false;

  /// Steps that apply to the answers as they stand: maintaining has no
  /// target weight or pace to set.
  List<OnboardingStep> _visible(OnboardingAnswers answers) => [
        for (final step in widget.steps)
          if (answers.goal != WeightGoal.maintain ||
              (step != OnboardingStep.targetWeight &&
                  step != OnboardingStep.pace))
            step,
      ];

  Future<void> _save(OnboardingAnswers answers) async {
    setState(() => _saving = true);
    final before = ref.read(storedProfileProvider);
    await ref.read(accountSyncProvider).saveProfile(answers);

    // A weight changed here is a weigh-in like any other, so the history and
    // the Progress chart agree with the profile.
    final kg = answers.weightKg;
    if (kg != null && kg != before?.weightKg) {
      await ref.read(weightLogProvider.notifier).log(DateTime.now(), kg);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final steps = _visible(state.answers);
    final complete = steps.every(
      (s) => state.copyWith(stepIndex: s.index).canAdvance,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          0,
          AppSpacing.screenMargin,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in steps) ..._section(step),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: complete && !_saving
                  ? () => _save(state.answers)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(OnboardingStep step) {
    final (_, question, hint, input) = onboardingStepContent(step);
    return [
      if (widget.steps.length > 1) ...[
        Text(question, style: AppTypography.headlineSmall),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: AppTypography.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
      input,
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}
