import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import 'data/food_repository.dart';
import 'domain/food_product.dart';
import 'food_product_screen.dart';
import 'widgets/food_widgets.dart';

/// Finds packaged food by name. Searches run when the user submits, not on
/// every keystroke, as Open Food Facts asks.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.mealType});

  final MealType? mealType;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController();

  /// Null until the first search.
  List<FoodProduct>? _results;
  String? _error;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2 || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(foodRepositoryProvider).search(q);
      if (mounted) setState(() => _results = results);
    } on FoodLookupException catch (e) {
      if (mounted) setState(() => _error = foodFailureMessage(e.reason));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _open(FoodProduct product) => context.push(
        AppRoutes.foodProduct,
        extra: FoodProductArgs(
          product: product,
          source: MealSource.search,
          mealType: widget.mealType,
        ),
      );

  Future<void> _relog(MealEntry entry) async {
    final now = DateTime.now();
    final type = widget.mealType ?? MealType.forTime(now);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(mealLogProvider.notifier)
        .relog(entry, type: type, loggedAt: logTimeFor(ref.read(selectedDayProvider)));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Added ${entry.name} to ${type.label}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentMealsProvider);
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Search food')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.xl,
          ),
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search foods and brands',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () => context.push(
                    Uri(
                      path: AppRoutes.barcodeScan,
                      queryParameters: {
                        if (widget.mealType case final t?) 'meal': t.name,
                      },
                    ).toString(),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan a barcode',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error case final error?)
              _Message(text: error, action: ('Try again', _search))
            else if (results != null) ...[
              if (results.isEmpty)
                const _Message(
                  text: 'No matches with nutrition data. Try another name, '
                      'or scan the barcode.',
                )
              else
                for (final product in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ResultTile(
                      product: product,
                      onTap: () => _open(product),
                    ),
                  ),
              const SizedBox(height: AppSpacing.md),
              const OpenFoodFactsCredit(),
            ] else ...[
              Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.photo_camera_rounded,
                      title: 'Scan food',
                      subtitle: 'From a photo',
                      onTap: () => context.pushReplacement(AppRoutes.scan),
                    ),
                  ),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.bolt_rounded,
                      title: 'Quick add',
                      subtitle: 'Type the calories',
                      onTap: () => context.pushReplacement(AppRoutes.quickAdd),
                    ),
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Recent', style: AppTypography.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final entry in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RecentTile(entry: entry, onAdd: () => _relog(entry)),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.product, required this.onTap});

  final FoodProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final perServing = product.servingGrams;
    final shown = perServing == null
        ? Portion(product, 100)
        : Portion(product, perServing);
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.nestedShape),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ProductImage(url: product.imageUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTypography.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand case final brand?)
                      Text(brand, style: AppTypography.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      '${shown.calories} kcal · P ${shown.proteinGrams}g · '
                      'C ${shown.carbGrams}g · F ${shown.fatGrams}g '
                      '${perServing == null ? 'per 100 g' : 'per serving'}',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.entry, required this.onAdd});

  final MealEntry entry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.nestedShape),
      child: ListTile(
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${entry.calories} kcal',
          style: AppTypography.bodySmall,
        ),
        trailing: IconButton.filledTonal(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Log ${entry.name} again',
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.nestedShape),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.calories),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.labelLarge),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Text(text, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
          if (action case (final label, final onPressed)) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onPressed, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
