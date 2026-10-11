import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/macro_stat.dart';
import '../log/widgets/meal_type_chips.dart';
import '../plan/plan_providers.dart';
import '../scan/data/meal_photo_service.dart';
import 'domain/meal_entry.dart';
import 'state/meal_log_controller.dart';

/// One logged meal: its photo if it has one, its numbers, and ways to edit,
/// log it again or delete it.
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});

  final String mealId;

  static String _sourceLabel(MealSource source) => switch (source) {
        MealSource.photo => 'Estimated from a photo',
        MealSource.barcode => 'From a barcode',
        MealSource.search => 'From food search',
        MealSource.quickAdd => 'Added by hand',
      };

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MealEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: Text(
          entry.photoPath == null
              ? '${entry.name} will be removed from your log.'
              : '${entry.name} and its photo will be removed from your log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final log = ref.read(mealLogProvider.notifier);
    context.pop();
    await log.remove(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${entry.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => log.restore(entry),
          ),
        ),
      );
  }

  Future<void> _logAgain(
    BuildContext context,
    WidgetRef ref,
    MealEntry entry,
  ) async {
    final now = DateTime.now();
    final type = MealType.forTime(now);
    await ref
        .read(mealLogProvider.notifier)
        .relog(entry, type: type, loggedAt: now);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Logged ${entry.name} again to ${type.label}')),
      );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MealEntry entry,
  ) async {
    final edited = await showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(entry: entry),
    );
    if (edited != null) {
      await ref.read(mealLogProvider.notifier).update(edited);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      mealLogProvider.select(
        (meals) => meals.where((m) => m.id == mealId).firstOrNull,
      ),
    );
    final plan = ref.watch(activePlanProvider);

    if (entry == null) {
      // Deleted here or on another device while open.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('This meal is no longer in your log.',
              style: AppTypography.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal'),
        actions: [
          IconButton(
            onPressed: () => _edit(context, ref, entry),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _delete(context, ref, entry),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
          ),
        ],
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
            if (entry.photoPath case final path?) ...[
              _MealPhoto(path: path),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(entry.name, style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${entry.type.label} · ${Dates.friendlyDay(entry.loggedAt)}, '
              '${Dates.time(entry.loggedAt)}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(_sourceLabel(entry.source), style: AppTypography.bodySmall),
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
                      text: groupedNumber(entry.calories),
                      style: AppTypography.metricHeadline,
                      children: [
                        TextSpan(
                          text: ' kcal',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Expanded(
                        child: MacroStat.protein(
                          grams: entry.proteinGrams,
                          goalGrams: plan?.proteinGrams ?? 0,
                        ),
                      ),
                      Expanded(
                        child: MacroStat.carbs(
                          grams: entry.carbGrams,
                          goalGrams: plan?.carbGrams ?? 0,
                        ),
                      ),
                      Expanded(
                        child: MacroStat.fat(
                          grams: entry.fatGrams,
                          goalGrams: plan?.fatGrams ?? 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _logAgain(context, ref, entry),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Log this again now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The meal's photo through a short-lived signed link, since the bucket is
/// private. Offline or expired, a placeholder stands in.
class _MealPhoto extends ConsumerStatefulWidget {
  const _MealPhoto({required this.path});

  final String path;

  @override
  ConsumerState<_MealPhoto> createState() => _MealPhotoState();
}

class _MealPhotoState extends ConsumerState<_MealPhoto> {
  late final Future<String> _url =
      ref.read(mealPhotoServiceProvider).viewUrl(widget.path);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.cardShape,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: AppColors.surface,
          child: FutureBuilder<String>(
            future: _url,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const _PhotoPlaceholder();
              final url = snapshot.data;
              if (url == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return Image.network(
                url,
                fit: BoxFit.cover,
                semanticLabel: 'Meal photo',
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Photo unavailable offline',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Corrects a logged meal: name, meal, calories and macros.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.entry});

  final MealEntry entry;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.entry.name);
  late final _calories =
      TextEditingController(text: '${widget.entry.calories}');
  late final _protein =
      TextEditingController(text: '${widget.entry.proteinGrams}');
  late final _carbs = TextEditingController(text: '${widget.entry.carbGrams}');
  late final _fat = TextEditingController(text: '${widget.entry.fatGrams}');
  late MealType _type = widget.entry.type;

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text) ?? 0;

  bool get _valid =>
      _name.text.trim().isNotEmpty && _calories.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
            Text('Edit meal', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Meal name'),
            ),
            MealTypeChips(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _calories,
                    label: 'kcal',
                    maxDigits: 5,
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
              onPressed: _valid
                  ? () => Navigator.of(context).pop(widget.entry.copyWith(
                        name: _name.text.trim(),
                        type: _type,
                        calories: _read(_calories),
                        proteinGrams: _read(_protein),
                        carbGrams: _read(_carbs),
                        fatGrams: _read(_fat),
                      ))
                  : null,
              child: const Text('Save changes'),
            ),
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
    this.maxDigits = 4,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxDigits;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(labelText: label),
    );
  }
}
