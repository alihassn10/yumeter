import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/home/widgets/calorie_summary_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: child),
      );

  testWidgets('summary card shows calories left when under budget',
      (tester) async {
    await tester.pumpWidget(host(const CalorieSummaryCard(
      consumed: 760,
      goal: 2000,
      proteinGrams: 92,
      proteinGoal: 140,
      carbsGrams: 140,
      carbsGoal: 310,
      fatGrams: 38,
      fatGoal: 70,
    )));

    expect(find.text('1240'), findsOneWidget);
    expect(find.text('Calories left'), findsOneWidget);
  });

  testWidgets('summary card switches to the over-budget label', (tester) async {
    await tester.pumpWidget(host(const CalorieSummaryCard(
      consumed: 2300,
      goal: 2000,
      proteinGrams: 150,
      proteinGoal: 140,
      carbsGrams: 320,
      carbsGoal: 310,
      fatGrams: 80,
      fatGoal: 70,
    )));

    expect(find.text('300'), findsOneWidget);
    expect(find.text('Calories over'), findsOneWidget);
  });
}
