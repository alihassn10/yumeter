import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';

/// Monday-to-Sunday strip for the week holding [selected]. Swiping moves a
/// week at a time; days after today are shown but cannot be picked.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.loggedDays,
    required this.onSelect,
    this.today,
  });

  final DateTime selected;
  final Set<DateTime> loggedDays;
  final ValueChanged<DateTime> onSelect;

  /// Injected by tests; defaults to the real current date.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = Dates.dateOnly(today ?? DateTime.now());
    final monday = Dates.startOfWeek(selected);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        // A leftward swipe advances, matching how a calendar pages.
        onSelect(Dates.addDays(selected, velocity < 0 ? 7 : -7));
      },
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _Day(
                date: Dates.addDays(monday, i),
                selected: Dates.isSameDay(Dates.addDays(monday, i), selected),
                isToday: Dates.addDays(monday, i) == now,
                logged: loggedDays.contains(Dates.addDays(monday, i)),
                future: Dates.addDays(monday, i).isAfter(now),
                onTap: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.logged,
    required this.future,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool logged;
  final bool future;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final label = Dates.weekdaysShort[date.weekday - 1];
    final foreground = selected
        ? context.colors.canvas
        : future
            ? context.colors.textHint.withValues(alpha: 0.5)
            : context.colors.textPrimary;

    return Semantics(
      button: !future,
      selected: selected,
      label: '${Dates.friendlyDay(date)}${logged ? ', logged' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: future ? null : () => onTap(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? context.colors.calories : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: isToday && !selected ? context.colors.outline : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Text(
                label.substring(0, 1),
                style: context.text.labelSmall.copyWith(
                  color: selected ? context.colors.canvas : context.colors.textHint,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${date.day}',
                style: context.text.labelLarge.copyWith(color: foreground),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: logged
                      ? (selected ? context.colors.canvas : context.colors.calories)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
