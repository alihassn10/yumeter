import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';
import '../../meals/domain/meal_entry.dart';

/// One logged meal in the day's list. Swiping it away deletes it; the caller
/// owns the undo.
class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.entry, required this.onDelete});

  final MealEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Only macros that were entered. A quick add with protein alone would
    // otherwise read "0g C 0g F", which claims zero rather than unknown.
    final macros = [
      if (entry.proteinGrams > 0)
        _macro('${entry.proteinGrams}g P', AppColors.protein),
      if (entry.carbGrams > 0) _macro('${entry.carbGrams}g C', AppColors.carbs),
      if (entry.fatGrams > 0) _macro('${entry.fatGrams}g F', AppColors.fat),
    ];

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.error),
          borderRadius: AppRadii.nestedShape,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.nestedShape,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.track,
                shape: BoxShape.circle,
              ),
              child: Icon(entry.type.icon, size: 20, color: AppColors.calories),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.name,
                    style: AppTypography.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.type.label} · ${Dates.time(entry.loggedAt)}',
                    style: AppTypography.bodySmall,
                  ),
                  if (macros.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.labelSmall,
                        children: [
                          for (final (i, macro) in macros.indexed) ...[
                            if (i > 0) const TextSpan(text: '   '),
                            macro,
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${entry.calories}', style: AppTypography.metricSub),
                Text('kcal', style: AppTypography.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _macro(String text, Color color) =>
      TextSpan(text: text, style: TextStyle(color: color));
}
