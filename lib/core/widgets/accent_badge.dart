import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// Compact stadium pill with an optional leading icon — used for the streak
/// counter, macro tags and micro-caps status badges.
class AccentBadge extends StatelessWidget {
  const AccentBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.tinted = false,
  });

  final String label;
  final IconData? icon;

  /// The accent; the palette's calorie orange when null.
  final Color? color;

  /// When true the fill is the accent at 12%; otherwise the neutral track.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.calories;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tinted ? AppColors.tint(color) : context.colors.track,
        borderRadius: AppRadii.pillShape,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
