import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/goal_calculator.dart';
import '../domain/onboarding_answers.dart';
import '../state/onboarding_controller.dart';
import '../widgets/choice_card.dart';
import '../widgets/ruler_picker.dart';

/// Vertical list of [ChoiceCard]s, the shape most quiz steps take.
class _ChoiceList extends StatelessWidget {
  const _ChoiceList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          child,
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class SexStep extends ConsumerWidget {
  const SexStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingControllerProvider).answers.sex;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return _ChoiceList(
      children: [
        for (final (sex, label, icon) in const [
          (Sex.female, 'Female', Icons.female_rounded),
          (Sex.male, 'Male', Icons.male_rounded),
          (Sex.other, 'Prefer not to say', Icons.person_outline_rounded),
        ])
          ChoiceCard(
            title: label,
            icon: icon,
            selected: selected == sex,
            onTap: () => controller.setSex(sex),
          ),
      ],
    );
  }
}

/// Age is collected rather than a full birth date: it is the only part the
/// calorie formula uses, and one wheel beats three.
class BirthDateStep extends ConsumerStatefulWidget {
  const BirthDateStep({super.key});

  static const minAge = 13;
  static const maxAge = 100;
  static const defaultAge = 25;

  @override
  ConsumerState<BirthDateStep> createState() => _BirthDateStepState();
}

class _BirthDateStepState extends ConsumerState<BirthDateStep> {
  late final FixedExtentScrollController _wheel;

  @override
  void initState() {
    super.initState();
    final answers = ref.read(onboardingControllerProvider).answers;
    final age = (answers.age ?? BirthDateStep.defaultAge)
        .clamp(BirthDateStep.minAge, BirthDateStep.maxAge);
    _wheel = FixedExtentScrollController(
      initialItem: age - BirthDateStep.minAge,
    );

    // The wheel already shows a value, so record it. Without this the step
    // looks answered but holds nothing, and Continue stays disabled until the
    // user happens to spin the wheel.
    if (answers.birthDate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setAge(age);
      });
    }
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  void _setAge(int age) {
    final now = DateTime.now();
    ref
        .read(onboardingControllerProvider.notifier)
        .setBirthDate(DateTime(now.year - age, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final age = ref.watch(onboardingControllerProvider).answers.age ??
        BirthDateStep.defaultAge;

    return SizedBox(
      height: 240,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 56,
        diameterRatio: 2.2,
        physics: const FixedExtentScrollPhysics(),
        controller: _wheel,
        onSelectedItemChanged: (index) =>
            _setAge(index + BirthDateStep.minAge),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: BirthDateStep.maxAge - BirthDateStep.minAge + 1,
          builder: (context, index) {
            final value = index + BirthDateStep.minAge;
            final isSelected = value == age;
            return Center(
              child: Text(
                '$value',
                style: isSelected
                    ? AppTypography.displaySmall
                    : AppTypography.headlineMedium
                        .copyWith(color: AppColors.textHint),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MeasurementsStep extends ConsumerStatefulWidget {
  const MeasurementsStep({super.key});

  static const defaultHeightCm = 170.0;
  static const defaultWeightKg = 70.0;

  @override
  ConsumerState<MeasurementsStep> createState() => _MeasurementsStepState();
}

class _MeasurementsStepState extends ConsumerState<MeasurementsStep> {
  @override
  void initState() {
    super.initState();
    // Both rulers open on a default, so record it for the same reason the age
    // wheel does: otherwise Continue stays disabled on a step that looks
    // answered.
    final answers = ref.read(onboardingControllerProvider).answers;
    if (answers.heightCm == null || answers.weightKg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(onboardingControllerProvider.notifier).setMeasurements(
              heightCm:
                  answers.heightCm ?? MeasurementsStep.defaultHeightCm,
              weightKg:
                  answers.weightKg ?? MeasurementsStep.defaultWeightKg,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingControllerProvider).answers;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final metric = answers.units == UnitSystem.metric;

    final heightCm = answers.heightCm ?? MeasurementsStep.defaultHeightCm;
    final weightKg = answers.weightKg ?? MeasurementsStep.defaultWeightKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UnitToggle(
          units: answers.units,
          onChanged: controller.setUnits,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Height', style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.md),
        if (metric)
          RulerPicker(
            value: heightCm,
            min: 120,
            max: 220,
            step: 1,
            majorEvery: 10,
            labelBuilder: (v) => '${v.round()} cm',
            onChanged: (v) => controller.setMeasurements(heightCm: v),
          )
        else
          RulerPicker(
            value: Units.cmToInch(heightCm),
            min: 47,
            max: 87,
            step: 1,
            majorEvery: 6,
            labelBuilder: (v) {
              final (feet, inches) = Units.cmToFeetInches(Units.inchToCm(v));
              return '$feet ft $inches in';
            },
            onChanged: (v) =>
                controller.setMeasurements(heightCm: Units.inchToCm(v)),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text('Weight', style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.md),
        if (metric)
          RulerPicker(
            value: weightKg,
            min: 30,
            max: 250,
            step: 0.1,
            majorEvery: 10,
            labelBuilder: (v) => '${v.toStringAsFixed(1)} kg',
            onChanged: (v) => controller.setMeasurements(weightKg: v),
          )
        else
          RulerPicker(
            value: Units.kgToLb(weightKg),
            min: 66,
            max: 550,
            step: 0.2,
            majorEvery: 25,
            labelBuilder: (v) => '${v.toStringAsFixed(1)} lb',
            onChanged: (v) =>
                controller.setMeasurements(weightKg: Units.lbToKg(v)),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.units, required this.onChanged});

  final UnitSystem units;
  final ValueChanged<UnitSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.pillShape,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (system, label) in const [
              (UnitSystem.metric, 'Metric'),
              (UnitSystem.imperial, 'Imperial'),
            ])
              GestureDetector(
                onTap: () => onChanged(system),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: units == system
                        ? AppColors.calories
                        : Colors.transparent,
                    borderRadius: AppRadii.pillShape,
                  ),
                  child: Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: units == system
                          ? AppColors.canvas
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityStep extends ConsumerWidget {
  const ActivityStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(onboardingControllerProvider).answers.activityLevel;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return _ChoiceList(
      children: [
        for (final level in ActivityLevel.values)
          ChoiceCard(
            title: level.label,
            description: level.description,
            icon: switch (level) {
              ActivityLevel.sedentary => Icons.weekend_rounded,
              ActivityLevel.light => Icons.directions_walk_rounded,
              ActivityLevel.moderate => Icons.directions_run_rounded,
              ActivityLevel.veryActive => Icons.fitness_center_rounded,
              ActivityLevel.extraActive => Icons.bolt_rounded,
            },
            selected: selected == level,
            onTap: () => controller.setActivityLevel(level),
          ),
      ],
    );
  }
}

class GoalStep extends ConsumerWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingControllerProvider).answers.goal;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return _ChoiceList(
      children: [
        for (final goal in WeightGoal.values)
          ChoiceCard(
            title: goal.label,
            description: goal.description,
            icon: switch (goal) {
              WeightGoal.lose => Icons.trending_down_rounded,
              WeightGoal.maintain => Icons.trending_flat_rounded,
              WeightGoal.gain => Icons.trending_up_rounded,
            },
            selected: selected == goal,
            onTap: () => controller.setGoal(goal),
          ),
      ],
    );
  }
}

class TargetWeightStep extends ConsumerWidget {
  const TargetWeightStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingControllerProvider).answers;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final metric = answers.units == UnitSystem.metric;

    final current = answers.weightKg ?? 70;
    final target = answers.targetWeightKg ?? current;
    final delta = target - current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metric)
          RulerPicker(
            value: target,
            min: 30,
            max: 250,
            step: 0.1,
            majorEvery: 10,
            labelBuilder: (v) => '${v.toStringAsFixed(1)} kg',
            onChanged: controller.setTargetWeight,
          )
        else
          RulerPicker(
            value: Units.kgToLb(target),
            min: 66,
            max: 550,
            step: 0.2,
            majorEvery: 25,
            labelBuilder: (v) => '${v.toStringAsFixed(1)} lb',
            onChanged: (v) => controller.setTargetWeight(Units.lbToKg(v)),
          ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            delta.abs() < 0.05
                ? 'Same as your current weight'
                : metric
                    ? '${delta.abs().toStringAsFixed(1)} kg to '
                        '${delta < 0 ? 'lose' : 'gain'}'
                    : '${Units.kgToLb(delta.abs()).toStringAsFixed(1)} lb to '
                        '${delta < 0 ? 'lose' : 'gain'}',
            style: AppTypography.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class PaceStep extends ConsumerWidget {
  const PaceStep({super.key});

  /// Above this the deficit is steep enough to be worth calling out.
  static const _aggressiveKgPerWeek = 0.9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingControllerProvider).answers;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final metric = answers.units == UnitSystem.metric;
    final pace = answers.paceKgPerWeek;

    final display = metric
        ? '${pace.toStringAsFixed(2)} kg'
        : '${Units.kgToLb(pace).toStringAsFixed(1)} lb';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(display, style: AppTypography.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text('per week', style: AppTypography.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Slider(
          value: pace,
          min: 0.1,
          max: 1.2,
          divisions: 22,
          activeColor: AppColors.calories,
          inactiveColor: AppColors.track,
          onChanged: controller.setPace,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gradual', style: AppTypography.bodySmall),
            Text('Steady', style: AppTypography.bodySmall),
            Text('Fast', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (pace > _aggressiveKgPerWeek)
          Container(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.carbs),
              borderRadius: AppRadii.nestedShape,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.carbs),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'A faster pace is harder to sustain and we will hold your '
                    'target above a safe minimum.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class DietStep extends ConsumerWidget {
  const DietStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingControllerProvider).answers.dietType;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return _ChoiceList(
      children: [
        for (final diet in DietType.values)
          ChoiceCard(
            title: diet.label,
            description: diet.description,
            icon: switch (diet) {
              DietType.balanced => Icons.restaurant_rounded,
              DietType.highProtein => Icons.egg_alt_rounded,
              DietType.lowCarb => Icons.grass_rounded,
              DietType.keto => Icons.water_drop_rounded,
              DietType.vegetarian => Icons.eco_rounded,
            },
            selected: selected == diet,
            onTap: () => controller.setDietType(diet),
          ),
      ],
    );
  }
}
