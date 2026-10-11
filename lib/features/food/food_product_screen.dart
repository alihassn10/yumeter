import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/macro_stat.dart';
import '../log/widgets/meal_type_chips.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import '../plan/plan_providers.dart';
import 'domain/food_product.dart';
import 'widgets/food_widgets.dart';

/// What the product screen needs: the product, how it was found, and the
/// meal the user started logging into.
class FoodProductArgs {
  const FoodProductArgs({
    required this.product,
    required this.source,
    this.mealType,
  });

  final FoodProduct product;
  final MealSource source;
  final MealType? mealType;
}

/// One packaged food: pick how much, see what it adds up to, log it.
class FoodProductScreen extends ConsumerStatefulWidget {
  const FoodProductScreen({super.key, required this.args});

  final FoodProductArgs args;

  @override
  ConsumerState<FoodProductScreen> createState() => _FoodProductScreenState();
}

class _FoodProductScreenState extends ConsumerState<FoodProductScreen> {
  FoodProduct get _product => widget.args.product;

  late MealType _type =
      widget.args.mealType ?? MealType.forTime(DateTime.now());

  /// Servings when the label gives a serving size, grams otherwise.
  late bool _byServing = _product.servingGrams != null;
  late double _servings = 1;
  late double _grams = _product.servingGrams ?? 100;
  bool _saving = false;

  double get _amountGrams =>
      _byServing ? _servings * _product.servingGrams! : _grams;

  void _step(int direction) => setState(() {
        if (_byServing) {
          _servings = math.max(0.5, _servings + 0.5 * direction);
        } else {
          _grams = math.max(5, (_grams / 5).round() * 5 + 5.0 * direction);
        }
      });

  String get _amountLabel {
    if (!_byServing) return '${_grams.round()} g';
    final count = _servings == _servings.roundToDouble()
        ? _servings.toInt().toString()
        : _servings.toString();
    return '$count × ${_product.servingLabel ?? '${_product.servingGrams!.round()} g serving'}';
  }

  Future<void> _editGrams() async {
    final controller = TextEditingController(text: '${_amountGrams.round()}');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Amount in grams'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'g'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0 && result <= 5000) {
      setState(() {
        _byServing = false;
        _grams = result;
      });
    }
  }

  Future<void> _log(Portion portion) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(mealLogProvider.notifier).add(
          type: _type,
          name: '${_product.displayName} (${_amountGrams.round()} g)',
          calories: portion.calories,
          proteinGrams: portion.proteinGrams,
          carbGrams: portion.carbGrams,
          fatGrams: portion.fatGrams,
          source: widget.args.source,
          loggedAt: logTimeFor(ref.read(selectedDayProvider)),
        );
    if (!mounted) return;
    context.go(AppRoutes.today);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${groupedNumber(portion.calories)} kcal to ${_type.label}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(activePlanProvider);
    final portion = Portion(_product, _amountGrams);

    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.xl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadii.cardShape,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductImage(url: _product.imageUrl, size: 88),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_product.brand case final brand?)
                              Text(
                                brand.toUpperCase(),
                                style: context.text.labelSmall,
                              ),
                            Text(
                              _product.name,
                              style: context.text.headlineSmall,
                            ),
                            if (_product.packageLabel case final pack?)
                              Text(pack, style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_product.servingGrams != null) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Servings')),
                        ButtonSegment(value: false, label: Text('Grams')),
                      ],
                      selected: {_byServing},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() {
                        _grams = _amountGrams;
                        _byServing = s.first;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _step(-1),
                        icon: const Icon(Icons.remove_rounded),
                        tooltip: 'Less',
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _editGrams,
                          borderRadius: AppRadii.pillShape,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _amountLabel,
                                  style: context.text.labelLarge,
                                  textAlign: TextAlign.center,
                                ),
                                if (_byServing)
                                  Text(
                                    '${_amountGrams.round()} g',
                                    style: context.text.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _step(1),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'More',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadii.cardShape,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: groupedNumber(portion.calories),
                      style: context.text.metricHeadline,
                      children: [
                        TextSpan(text: ' kcal', style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                  if (plan != null)
                    Text(
                      '${(portion.calories / plan.calories * 100).round()}% of '
                      'your ${groupedNumber(plan.calories)} kcal daily target',
                      style: context.text.bodySmall,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Expanded(
                        child: MacroStat.protein(
                          grams: portion.proteinGrams,
                          goalGrams: plan?.proteinGrams ?? 0,
                        ),
                      ),
                      Expanded(
                        child: MacroStat.carbs(
                          grams: portion.carbGrams,
                          goalGrams: plan?.carbGrams ?? 0,
                        ),
                      ),
                      Expanded(
                        child: MacroStat.fat(
                          grams: portion.fatGrams,
                          goalGrams: plan?.fatGrams ?? 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Per 100 g: ${_product.kcalPer100g.round()} kcal · '
                    'P ${_product.proteinPer100g.toStringAsFixed(1)} g · '
                    'C ${_product.carbPer100g.toStringAsFixed(1)} g · '
                    'F ${_product.fatPer100g.toStringAsFixed(1)} g',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Log to', style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            MealTypeChips(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _saving ? null : () => _log(portion),
              child: Text(
                'Log ${groupedNumber(portion.calories)} kcal to ${_type.label}',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const OpenFoodFactsCredit(),
          ],
        ),
      ),
    );
  }
}
