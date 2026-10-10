import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../meals/domain/meal_entry.dart';

/// Single-select row of meal types.
///
/// The four chips are wider than most phones, so the row scrolls — and it
/// scrolls the selected chip into view, or a preselected "Snack" would sit
/// clipped off the right edge where nobody can see it is chosen.
class MealTypeChips extends StatefulWidget {
  const MealTypeChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MealType selected;
  final ValueChanged<MealType> onChanged;

  @override
  State<MealTypeChips> createState() => _MealTypeChipsState();
}

class _MealTypeChipsState extends State<MealTypeChips> {
  final _controller = ScrollController();
  final _keys = {for (final type in MealType.values) type: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(MealTypeChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Centres the selected chip in this row only. `Scrollable.ensureVisible`
  /// would also scroll every enclosing list, dragging the whole sheet.
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final box = _keys[widget.selected]!.currentContext?.findRenderObject();
      if (box is! RenderBox) return;

      final position = _controller.position;
      final target = RenderAbstractViewport.of(box)
          .getOffsetToReveal(box, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);

      if (animate) {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in MealType.values) ...[
            if (type != MealType.values.first)
              const SizedBox(width: AppSpacing.sm),
            _Chip(
              key: _keys[type],
              type: type,
              selected: type == widget.selected,
              onTap: () => widget.onChanged(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MealType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.canvas : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.calories : AppColors.track,
            borderRadius: AppRadii.pillShape,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(
                type.label,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
