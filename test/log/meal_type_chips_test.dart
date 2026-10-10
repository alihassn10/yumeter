import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/home/widgets/meal_tile.dart';
import 'package:yumeter/features/log/widgets/meal_type_chips.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';

void main() {
  // Found on the device: with Snack preselected at 3:52 PM, the chip sat
  // clipped off the right edge, so nothing visibly showed it was chosen.
  testWidgets('the selected chip is scrolled fully into view', (tester) async {
    const rowWidth = 300.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: rowWidth,
              child: MealTypeChips(
                selected: MealType.snack,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = tester.getRect(find.byType(MealTypeChips));
    final chip = tester.getRect(find.text('Snack'));
    expect(chip.left, greaterThanOrEqualTo(row.left));
    expect(chip.right, lessThanOrEqualTo(row.right));
  });

  testWidgets('a meal row lists only the macros that were entered',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: MealTile(
            entry: MealEntry(
              id: 'x',
              loggedAt: DateTime(2026, 10, 10, 15, 53),
              type: MealType.snack,
              name: 'Quick add',
              calories: 450,
              proteinGrams: 30,
            ),
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('30g P', findRichText: true), findsOneWidget);
    expect(find.textContaining('0g C', findRichText: true), findsNothing);
    expect(find.textContaining('0g F', findRichText: true), findsNothing);
  });
}
