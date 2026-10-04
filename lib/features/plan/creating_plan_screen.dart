import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/calorie_ring.dart';
import '../onboarding/state/onboarding_controller.dart';

/// One line of the setup checklist.
class _Stage {
  const _Stage(this.title, this.detail);

  final String title;
  final String detail;
}

const _stages = [
  _Stage('Working out your baseline', 'Energy burned at rest'),
  _Stage('Adding your activity', 'Workouts and daily movement'),
  _Stage('Setting your daily calories', 'Adjusted for your goal and pace'),
  _Stage('Splitting your macros', 'Protein, carbs and fat'),
];

/// The beat between finishing the quiz and seeing the plan. The work itself is
/// instant, so the staging is presentational — it gives the result weight and
/// a moment to save the profile.
class CreatingPlanScreen extends ConsumerStatefulWidget {
  const CreatingPlanScreen({super.key});

  static const stageDuration = Duration(milliseconds: 850);

  @override
  ConsumerState<CreatingPlanScreen> createState() => _CreatingPlanScreenState();
}

class _CreatingPlanScreenState extends ConsumerState<CreatingPlanScreen> {
  int _completed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    // Persist first: if anything below is interrupted the answers are safe.
    final answers = ref.read(onboardingControllerProvider).answers;
    await ref.read(profileStoreProvider).save(answers);

    for (var i = 1; i <= _stages.length; i++) {
      await Future<void>.delayed(CreatingPlanScreen.stageDuration);
      if (!mounted) return;
      setState(() => _completed = i);
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    context.go(AppRoutes.planReveal);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completed / _stages.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: Column(
            children: [
              const Spacer(),
              CalorieRing(
                progress: progress,
                size: 180,
                strokeWidth: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: AppTypography.displaySmall,
                    ),
                    Text('Building', style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Putting your plan together',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final (i, stage) in _stages.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _StageRow(
                  stage: stage,
                  done: i < _completed,
                  active: i == _completed,
                ),
              ],
              const Spacer(),
              Text(
                'Keep the app open for a moment.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.done,
    required this.active,
  });

  final _Stage stage;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Stages below the current one stay dimmed so the eye lands on what is
    // happening now.
    final pending = !done && !active;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: pending ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.nestedShape,
          border: Border.all(
            color: active ? AppColors.calories : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: done
                  ? const Icon(
                      Icons.check_circle_rounded,
                      size: 24,
                      color: AppColors.success,
                    )
                  : active
                      ? const CircularProgressIndicator(strokeWidth: 2.5)
                      : const Icon(
                          Icons.circle_outlined,
                          size: 24,
                          color: AppColors.textHint,
                        ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(stage.title, style: AppTypography.headlineSmall),
                  const SizedBox(height: 2),
                  Text(stage.detail, style: AppTypography.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
