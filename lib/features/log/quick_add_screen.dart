import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import 'widgets/meal_type_chips.dart';

/// Which value the keypad is editing.
enum QuickAddField {
  calories('Calories', 4),
  protein('Protein', 3),
  carbs('Carbs', 3),
  fat('Fat', 3);

  const QuickAddField(this.label, this.maxDigits);

  final String label;

  /// Caps entry at 9,999 kcal and 999 g, well past any single meal.
  final int maxDigits;
}

/// Manual logging for when there is no photo or barcode — calories required,
/// macros optional.
class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key, this.initialType});

  final MealType? initialType;

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  late MealType _type = widget.initialType ?? MealType.forTime(DateTime.now());
  final _values = {for (final f in QuickAddField.values) f: 0};
  QuickAddField _active = QuickAddField.calories;
  String? _name;
  bool _saving = false;

  int get _calories => _values[QuickAddField.calories]!;
  int get _protein => _values[QuickAddField.protein]!;
  int get _carbs => _values[QuickAddField.carbs]!;
  int get _fat => _values[QuickAddField.fat]!;

  int get _macroCalories => _protein * 4 + _carbs * 4 + _fat * 9;

  /// Flags macros that disagree with the calorie figure by more than rounding
  /// on a label would explain.
  ///
  /// Macros above the total are wrong however many are still blank. Macros
  /// below it only mean something once all three are in — until then the user
  /// simply has not finished typing, and offering to replace the calories
  /// with a partial sum would be wrong.
  bool get _macrosDisagree {
    final entered = [_protein, _carbs, _fat].where((g) => g > 0).length;
    if (entered == 0) return false;
    final tolerance = math.max(50, _calories * 0.15);
    final excess = _macroCalories - _calories;
    if (excess > tolerance) return true;
    return entered == 3 && -excess > tolerance;
  }

  void _set(QuickAddField field, int value) {
    HapticFeedback.selectionClick();
    setState(() => _values[field] = value);
  }

  void _digit(int d) {
    final next = _values[_active]! * 10 + d;
    if (next.toString().length > _active.maxDigits) return;
    _set(_active, next);
  }

  void _backspace() => _set(_active, _values[_active]! ~/ 10);

  void _clear() => _set(_active, 0);

  void _increment(int by) {
    _active = QuickAddField.calories;
    _set(QuickAddField.calories, math.min(9999, _calories + by));
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Name this meal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Chicken wrap'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final trimmed = result.trim();
    setState(() => _name = trimmed.isEmpty ? null : trimmed);
  }

  Future<void> _log() async {
    if (_calories == 0 || _saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final day = ref.read(selectedDayProvider);
    await ref.read(mealLogProvider.notifier).add(
          type: _type,
          name: _name ?? 'Quick add',
          calories: _calories,
          proteinGrams: _protein,
          carbGrams: _carbs,
          fatGrams: _fat,
          loggedAt: logTimeFor(day),
        );

    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${groupedNumber(_calories)} kcal to ${_type.label}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        title: const Text('Quick add'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MealTypeChips(
                      selected: _type,
                      onChanged: (type) => setState(() => _type = type),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _CalorieDisplay(
                      calories: _calories,
                      active: _active == QuickAddField.calories,
                      onTap: () =>
                          setState(() => _active = QuickAddField.calories),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: _editName,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(_name ?? 'Add a name'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: AppSpacing.sm,
                      children: [
                        for (final by in const [50, 100, 250])
                          ActionChip(
                            label: Text('+$by'),
                            onPressed: () => _increment(by),
                            backgroundColor: AppColors.track,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            labelStyle: AppTypography.labelMedium
                                .copyWith(color: AppColors.textPrimary),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final (field, color) in const [
                          (QuickAddField.protein, AppColors.protein),
                          (QuickAddField.carbs, AppColors.carbs),
                          (QuickAddField.fat, AppColors.fat),
                        ])
                          Expanded(
                            child: _MacroField(
                              label: field.label,
                              grams: _values[field]!,
                              color: color,
                              active: _active == field,
                              onTap: () => setState(() => _active = field),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Reserves the line so the keypad does not jump when the
                    // hint appears.
                    SizedBox(
                      height: 40,
                      child: _macrosDisagree
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColors.carbs,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Macros add up to '
                                    '${groupedNumber(_macroCalories)} kcal',
                                    style: AppTypography.bodySmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _active = QuickAddField.calories;
                                    _set(
                                      QuickAddField.calories,
                                      math.min(9999, _macroCalories),
                                    );
                                  },
                                  child: const Text('Use that'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            _Keypad(
              onDigit: _digit,
              onBackspace: _backspace,
              onClear: _clear,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.lg,
              ),
              child: ElevatedButton(
                onPressed: _calories == 0 || _saving ? null : _log,
                child: Text(
                  _calories == 0
                      ? 'Enter calories'
                      : 'Log ${groupedNumber(_calories)} kcal to '
                          '${_type.label}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieDisplay extends StatelessWidget {
  const _CalorieDisplay({
    required this.calories,
    required this.active,
    required this.onTap,
  });

  final int calories;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Calories',
      value: '$calories',
      selected: active,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: groupedNumber(calories),
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 56,
                  color: calories == 0
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: ' kcal',
                    style: AppTypography.headlineSmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              height: 3,
              decoration: BoxDecoration(
                color: active ? AppColors.calories : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  const _MacroField({
    required this.label,
    required this.grams,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int grams;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: grams == 0 ? 'not set' : '$grams grams',
      selected: active,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.nestedShape,
            border: Border.all(
              color: active ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                grams == 0 ? '–' : '${grams}g',
                style: AppTypography.metricSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget key({
      required Widget child,
      required VoidCallback onTap,
      String? semanticLabel,
    }) =>
        Expanded(
          child: Semantics(
            button: true,
            label: semanticLabel,
            // Without this the visible "C" is read out after "Clear".
            excludeSemantics: semanticLabel != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: SizedBox(height: 56, child: Center(child: child)),
            ),
          ),
        );

    Widget digit(int d) => key(
          onTap: () => onDigit(d),
          child: Text('$d', style: AppTypography.headlineMedium),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(children: [for (final d in row) digit(d)]),
          Row(
            children: [
              key(
                onTap: onClear,
                semanticLabel: 'Clear',
                child: Text(
                  'C',
                  style: AppTypography.headlineMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              digit(0),
              key(
                onTap: onBackspace,
                semanticLabel: 'Delete',
                child: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
