import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/profile_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../onboarding/domain/goal_calculator.dart';
import '../onboarding/domain/onboarding_answers.dart';
import '../onboarding/widgets/ruler_picker.dart';
import 'domain/weight_entry.dart';
import 'state/weight_log_controller.dart';

/// Opens the sheet for today's weigh-in.
Future<void> showWeightLogSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WeightLogSheet(),
    );

/// Logs today's weight. Stored in kilograms; shown in the user's units.
class WeightLogSheet extends ConsumerStatefulWidget {
  const WeightLogSheet({super.key});

  @override
  ConsumerState<WeightLogSheet> createState() => _WeightLogSheetState();
}

class _WeightLogSheetState extends ConsumerState<WeightLogSheet> {
  late final DateTime _today = Dates.dateOnly(DateTime.now());
  late final bool _imperial =
      ref.read(storedProfileProvider)?.units == UnitSystem.imperial;

  /// The value on the ruler, in display units.
  late double _value = _toDisplay(_startingKg());
  bool _saving = false;

  /// Today's entry if there is one, else the latest weigh-in, else the
  /// onboarding weight, so the ruler opens where the user probably is.
  double _startingKg() {
    final weights = ref.read(weightLogProvider);
    for (final w in weights.reversed) {
      if (w.day == _today) return w.weightKg;
    }
    return weights.lastOrNull?.weightKg ??
        ref.read(storedProfileProvider)?.weightKg ??
        70;
  }

  double _toDisplay(double kg) => _imperial ? Units.kgToLb(kg) : kg;
  double _toKg(double v) => _imperial ? Units.lbToKg(v) : v;
  String get _unit => _imperial ? 'lb' : 'kg';

  Future<void> _save() async {
    setState(() => _saving = true);
    final kg = (_toKg(_value) * 10).round() / 10;
    await ref.read(weightLogProvider.notifier).log(_today, kg);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Logged ${_value.toStringAsFixed(1)} $_unit')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weights = ref.watch(weightLogProvider);
    final profile = ref.watch(storedProfileProvider);
    final previous = weights.lastWhereOrNull((w) => w.day.isBefore(_today));

    return Padding(
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
          Text("Log today's weight", style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(Dates.friendlyDay(_today), style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text.rich(
              TextSpan(
                text: _value.toStringAsFixed(1),
                style: AppTypography.displaySmall,
                children: [
                  TextSpan(text: ' $_unit', style: AppTypography.bodyLarge),
                ],
              ),
            ),
          ),
          if (previous != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Center(child: _Change(previous: previous, now: _value, sheet: this)),
          ],
          const SizedBox(height: AppSpacing.md),
          RulerPicker(
            value: _value,
            min: _imperial ? 66 : 30,
            max: _imperial ? 550 : 250,
            onChanged: (v) => setState(() => _value = v),
            labelBuilder: (v) => v.toStringAsFixed(0),
          ),
          if (_goalLine(profile) case final line?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              line,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save weight'),
          ),
        ],
      ),
    );
  }

  /// How far the ruler's weight is from the goal, or null without one.
  String? _goalLine(OnboardingAnswers? profile) {
    final target = profile?.targetWeightKg;
    if (target == null || profile?.goal == WeightGoal.maintain) return null;
    final remaining = _toKg(_value) - target;
    final reached = profile?.goal == WeightGoal.lose
        ? remaining <= 0.05
        : remaining >= -0.05;
    if (reached) return 'At or past your goal of ${_fmt(target)}.';
    return '${_toDisplay(remaining.abs()).toStringAsFixed(1)} $_unit to go '
        'to your goal of ${_fmt(target)}.';
  }

  String _fmt(double kg) => '${_toDisplay(kg).toStringAsFixed(1)} $_unit';
}

class _Change extends StatelessWidget {
  const _Change({
    required this.previous,
    required this.now,
    required this.sheet,
  });

  final WeightEntry previous;
  final double now;
  final _WeightLogSheetState sheet;

  @override
  Widget build(BuildContext context) {
    final delta = now - sheet._toDisplay(previous.weightKg);
    final sign = delta > 0.05 ? '+' : delta < -0.05 ? '−' : '±';
    return Text(
      '$sign${delta.abs().toStringAsFixed(1)} ${sheet._unit} since '
      '${Dates.friendlyDay(previous.day)}',
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (final e in reversed) {
      if (test(e)) return e;
    }
    return null;
  }
}
