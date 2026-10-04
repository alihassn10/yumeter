import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';

/// A selectable option row in the onboarding quiz: icon, title, optional
/// description and badge, with a trailing radio dot.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    this.icon,
    this.badge,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.nestedShape,
          border: Border.all(
            color: selected ? AppColors.calories : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.nestedShape,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.nestedShape,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.tint(AppColors.calories)
                            : AppColors.track,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: selected
                            ? AppColors.calories
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: AppTypography.headlineSmall,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tint(AppColors.calories),
                                  borderRadius: AppRadii.pillShape,
                                ),
                                child: Text(
                                  badge!,
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.calories),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(description!, style: AppTypography.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _RadioDot(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.calories : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.calories : AppColors.outline,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.canvas)
          : null,
    );
  }
}
