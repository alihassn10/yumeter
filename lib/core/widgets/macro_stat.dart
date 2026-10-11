import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// One column of the macro strip: gram count, label, and a slim progress track
/// tinted with that macro's accent.
class MacroStat extends StatelessWidget {
  const MacroStat({
    super.key,
    required this.label,
    required this.grams,
    required this.goalGrams,
    required Color this.color,
  }) : _accent = null;

  final String label;
  final int grams;
  final int goalGrams;

  /// An explicit accent, or null to use the named macro's palette colour.
  final Color? color;
  final _Macro? _accent;

  const MacroStat.protein({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Protein',
        color = null,
        _accent = _Macro.protein;

  const MacroStat.carbs({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Carbs',
        color = null,
        _accent = _Macro.carbs;

  const MacroStat.fat({
    super.key,
    required this.grams,
    required this.goalGrams,
  })  : label = 'Fat',
        color = null,
        _accent = _Macro.fat;

  @override
  Widget build(BuildContext context) {
    final color = this.color ??
        switch (_accent!) {
          _Macro.protein => context.colors.protein,
          _Macro.carbs => context.colors.carbs,
          _Macro.fat => context.colors.fat,
        };
    // A zero goal would make the ratio undefined; show an empty track instead.
    final progress = goalGrams <= 0 ? 0.0 : (grams / goalGrams).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceNested,
        borderRadius: AppRadii.nestedShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${grams}g', style: context.text.metricSub),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                color: color,
                backgroundColor: context.colors.track,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which macro a named constructor stands for; its colour comes from the
/// palette at build time, so it follows light and dark mode.
enum _Macro { protein, carbs, fat }
