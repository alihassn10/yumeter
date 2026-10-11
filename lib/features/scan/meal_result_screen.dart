import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/macro_stat.dart';
import '../auth/data/auth_repository.dart';
import '../log/widgets/meal_type_chips.dart';
import '../meals/domain/meal_entry.dart';
import '../meals/state/meal_log_controller.dart';
import '../plan/plan_providers.dart';
import 'data/meal_photo_service.dart';
import 'domain/meal_draft.dart';
import 'domain/picked_photo.dart';

/// Uploads a meal photo, shows the estimate, and lets the user correct it
/// before anything is logged.
class MealResultScreen extends ConsumerStatefulWidget {
  const MealResultScreen({super.key, required this.photo});

  final PickedPhoto photo;

  @override
  ConsumerState<MealResultScreen> createState() => _MealResultScreenState();
}

class _MealResultScreenState extends ConsumerState<MealResultScreen> {
  static const _uuid = Uuid();

  /// Chosen up front so the photo can be stored under the meal's own id.
  final _mealId = _uuid.v4();

  late final MealPhotoService _service = ref.read(mealPhotoServiceProvider);
  late MealType _type = MealType.forTime(DateTime.now());

  String? _photoPath;
  MealDraft? _draft;
  AnalysisFailureKind? _failure;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    // Leaving without logging: the photo belongs to no meal, so drop it.
    final path = _photoPath;
    if (!_saved && path != null) {
      unawaited(_service.remove(path).catchError((Object e) {
        debugPrint('Could not remove unused photo $path: $e');
      }));
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _failure = null;
      _draft = null;
    });
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _failure = AnalysisFailureKind.failed);
      return;
    }
    try {
      // A retry after a failed analysis reuses the photo already uploaded.
      final path = _photoPath ??= await _service.upload(
        userId: user.id,
        mealId: _mealId,
        bytes: widget.photo.bytes,
        extension: widget.photo.extension,
      );
      final draft = await _service.analyze(path);
      if (mounted) setState(() => _draft = draft);
    } on AnalysisFailure catch (e) {
      if (mounted) setState(() => _failure = e.kind);
    }
  }

  Future<void> _log() async {
    final draft = _draft;
    if (draft == null || !draft.canSave || _saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(mealLogProvider.notifier).add(
          id: _mealId,
          type: _type,
          name: draft.name,
          calories: draft.calories,
          proteinGrams: draft.proteinGrams,
          carbGrams: draft.carbGrams,
          fatGrams: draft.fatGrams,
          source: MealSource.photo,
          photoPath: _photoPath,
          loggedAt: logTimeFor(ref.read(selectedDayProvider)),
        );
    _saved = true;

    if (!mounted) return;
    context.go(AppRoutes.today);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${groupedNumber(draft.calories)} kcal to ${_type.label}',
        ),
      ),
    );
  }

  Future<void> _rename() async {
    final draft = _draft;
    if (draft == null) return;
    final name = await _askText(
      context,
      title: 'Name this meal',
      initial: draft.name,
      maxLength: 60,
    );
    if (name != null) setState(() => _draft = draft.withName(name));
  }

  Future<void> _editItem(int? index) async {
    final draft = _draft;
    if (draft == null) return;
    final result = await showModalBottomSheet<_ItemEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(
        item: index == null ? null : draft.items[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = switch ((result, index)) {
        (_ItemRemoved(), final i?) => draft.withoutItem(i),
        (_ItemSaved(:final item), final i?) => draft.withItem(i, item),
        (_ItemSaved(:final item), null) => draft.withAddedItem(item),
        _ => draft,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        title: const Text('Review meal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.xl,
          ),
          children: [
            ClipRRect(
              borderRadius: AppRadii.cardShape,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(widget.photo.bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (failure != null)
              _FailureCard(
                kind: failure,
                onRetry: _analyze,
                onRetake: () => context.pop(),
                onTypeItIn: () => context.pushReplacement(AppRoutes.quickAdd),
                onSearch: () => context.pushReplacement(AppRoutes.foodSearch),
              )
            else if (draft == null)
              const _Analyzing()
            else
              ..._review(draft),
          ],
        ),
      ),
      bottomNavigationBar: draft == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.sm,
                AppSpacing.screenMargin,
                AppSpacing.md,
              ),
              child: ElevatedButton(
                onPressed: draft.canSave && !_saving ? _log : null,
                child: Text(
                  draft.canSave
                      ? 'Log ${groupedNumber(draft.calories)} kcal'
                      : 'Add a food to log this meal',
                ),
              ),
            ),
    );
  }

  List<Widget> _review(MealDraft draft) {
    final plan = ref.watch(activePlanProvider);
    return [
      InkWell(
        onTap: _rename,
        borderRadius: AppRadii.nestedShape,
        child: Row(
          children: [
            Expanded(
              child: Text(draft.name, style: AppTypography.headlineMedium),
            ),
            const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Estimated from your photo. Tap any food to adjust it.',
        style: AppTypography.bodySmall,
      ),
      const SizedBox(height: AppSpacing.lg),
      MealTypeChips(
        selected: _type,
        onChanged: (type) => setState(() => _type = type),
      ),
      const SizedBox(height: AppSpacing.lg),
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardShape,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: groupedNumber(draft.calories),
                style: AppTypography.metricHeadline,
                children: [
                  TextSpan(text: ' kcal', style: AppTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Bars show this meal against the day's targets.
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: MacroStat.protein(
                    grams: draft.proteinGrams,
                    goalGrams: plan?.proteinGrams ?? 0,
                  ),
                ),
                Expanded(
                  child: MacroStat.carbs(
                    grams: draft.carbGrams,
                    goalGrams: plan?.carbGrams ?? 0,
                  ),
                ),
                Expanded(
                  child: MacroStat.fat(
                    grams: draft.fatGrams,
                    goalGrams: plan?.fatGrams ?? 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(child: Text('Foods', style: AppTypography.labelLarge)),
          TextButton.icon(
            onPressed: () => _editItem(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add food'),
          ),
        ],
      ),
      for (final (index, item) in draft.items.indexed)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: _ItemTile(item: item, onTap: () => _editItem(index)),
        ),
      if (draft.items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text('No foods left.', style: AppTypography.bodyMedium),
        ),
    ];
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text('Analysing your meal…', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This usually takes a few seconds.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.kind,
    required this.onRetry,
    required this.onRetake,
    required this.onTypeItIn,
    required this.onSearch,
  });

  final AnalysisFailureKind kind;
  final VoidCallback onSearch;
  final VoidCallback onRetry;
  final VoidCallback onRetake;
  final VoidCallback onTypeItIn;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (kind) {
      AnalysisFailureKind.notFood => (
          'No food found',
          'We could not spot any food or drink in this photo. Try another '
              'angle, or type the meal in.',
        ),
      AnalysisFailureKind.rateLimited => (
          'Busy right now',
          'Photo analysis is busy right now. Try again in a minute.',
        ),
      AnalysisFailureKind.offline => (
          'You are offline',
          'Photo logging needs a connection. Typing a meal in works offline.',
        ),
      AnalysisFailureKind.failed => (
          'Something went wrong',
          'The photo could not be analysed. Try again.',
        ),
      AnalysisFailureKind.dailyLimit => (
          'Daily photo limit reached',
          'You have used today\'s photo analyses. They reset at midnight UTC. '
              'Search, barcode scanning and typing a meal in still work.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          switch (kind) {
            AnalysisFailureKind.notFood => ElevatedButton(
                onPressed: onRetake,
                child: const Text('Take another photo'),
              ),
            // Retrying cannot help until tomorrow; point to what still works.
            AnalysisFailureKind.dailyLimit => ElevatedButton(
                onPressed: onSearch,
                child: const Text('Search food'),
              ),
            _ => ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
          },
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onTypeItIn,
            child: const Text('Type it in instead'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap});

  final DraftItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (item.portion.isNotEmpty) item.portion,
      'P ${item.proteinGrams}g · C ${item.carbGrams}g · F ${item.fatGrams}g',
    ].join('  ·  ');

    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.nestedShape),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text(detail, style: AppTypography.bodySmall),
        trailing: Text(
          '${groupedNumber(item.calories)} kcal',
          style: AppTypography.labelLarge,
        ),
      ),
    );
  }
}

/// What the item sheet decided.
sealed class _ItemEdit {
  const _ItemEdit();
}

class _ItemSaved extends _ItemEdit {
  const _ItemSaved(this.item);

  final DraftItem item;
}

class _ItemRemoved extends _ItemEdit {
  const _ItemRemoved();
}

/// Edits one food, or adds a new one when [item] is null.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({this.item});

  final DraftItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  static const _portions = [0.5, 1.0, 1.5, 2.0];

  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _calories = _number(widget.item?.calories);
  late final _protein = _number(widget.item?.proteinGrams);
  late final _carbs = _number(widget.item?.carbGrams);
  late final _fat = _number(widget.item?.fatGrams);
  double _portion = 1;

  static TextEditingController _number(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rescales every figure from the original estimate, so switching between
  /// portions never compounds rounding.
  void _setPortion(double factor) {
    final original = widget.item;
    if (original == null) return;
    final scaled = original.scaled(factor);
    setState(() {
      _portion = factor;
      _calories.text = '${scaled.calories}';
      _protein.text = '${scaled.proteinGrams}';
      _carbs.text = '${scaled.carbGrams}';
      _fat.text = '${scaled.fatGrams}';
    });
  }

  int _read(TextEditingController c) => int.tryParse(c.text) ?? 0;

  bool get _valid => _name.text.trim().isNotEmpty && _calories.text.isNotEmpty;

  void _save() {
    final original = widget.item;
    final portion = original == null
        ? ''
        : original.scaled(_portion).portion;
    Navigator.of(context).pop(_ItemSaved(DraftItem(
      name: _name.text.trim(),
      portion: portion,
      calories: _read(_calories),
      proteinGrams: _read(_protein),
      carbGrams: _read(_carbs),
      fatGrams: _read(_fat),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Adjust food' : 'Add food',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Food name'),
            ),
            if (editing) ...[
              Text('Portion', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final factor in _portions)
                    ChoiceChip(
                      label: Text(factor == 0.5
                          ? '½×'
                          : factor == 1.5
                              ? '1½×'
                              : '${factor.toInt()}×'),
                      selected: _portion == factor,
                      onSelected: (_) => _setPortion(factor),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _calories,
                    label: 'kcal',
                    onChanged: () => setState(() {}),
                  ),
                ),
                Expanded(
                  child: _NumberField(controller: _protein, label: 'Protein g'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: _NumberField(controller: _carbs, label: 'Carbs g'),
                ),
                Expanded(
                  child: _NumberField(controller: _fat, label: 'Fat g'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _valid ? _save : null,
              child: Text(editing ? 'Save' : 'Add'),
            ),
            if (editing) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(const _ItemRemoved()),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Remove from meal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      // Caps match the meals table: 20,000 kcal and 2,000 g per meal.
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(label == 'kcal' ? 5 : 4),
      ],
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(labelText: label),
    );
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxLength,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
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
  return result;
}
