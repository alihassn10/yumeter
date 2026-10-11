import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/progress/domain/progress_stats.dart';
import 'package:yumeter/features/progress/domain/weight_entry.dart';

void main() {
  // A Saturday, so week buckets are easy to reason about.
  final today = DateTime(2026, 10, 11, 20);

  MealEntry meal(DateTime at, int kcal, {int p = 0, int c = 0, int f = 0}) =>
      MealEntry(
        id: '${at.toIso8601String()}-$kcal',
        loggedAt: at,
        type: MealType.lunch,
        name: 'Meal',
        calories: kcal,
        proteinGrams: p,
        carbGrams: c,
        fatGrams: f,
      );

  group('summarize', () {
    test('averages over logged days only, not empty ones', () {
      final meals = [
        meal(DateTime(2026, 10, 11, 9), 500),
        meal(DateTime(2026, 10, 11, 13), 700),
        meal(DateTime(2026, 10, 9, 13), 1800),
      ];
      final s = summarize(meals, ProgressRange.week, today: today);

      expect(s.daysInRange, 7);
      expect(s.loggedDays, 2);
      // (1200 + 1800) / 2 logged days, not / 7.
      expect(s.averageCalories, 1500);
    });

    test('a week has seven daily bars, empty where nothing was logged', () {
      final s = summarize(
        [meal(DateTime(2026, 10, 11, 9), 500)],
        ProgressRange.week,
        today: today,
      );
      expect(s.bars, hasLength(7));
      expect(s.bars.last.calories, 500);
      expect(s.bars.first.hasData, isFalse);
      expect(s.bars.every((b) => b.span == BarSpan.day), isTrue);
    });

    test('three months groups into weekly averages', () {
      final s = summarize(
        [
          meal(DateTime(2026, 10, 5, 12), 2000), // Monday
          meal(DateTime(2026, 10, 6, 12), 1000), // same week
        ],
        ProgressRange.quarter,
        today: today,
      );
      final week = s.bars.firstWhere((b) => b.hasData);
      expect(week.span, BarSpan.week);
      expect(week.calories, 1500);
      expect(week.loggedDays, 2);
    });

    test('ignores meals outside the range', () {
      final s = summarize(
        [meal(DateTime(2026, 9, 1, 12), 900)],
        ProgressRange.week,
        today: today,
      );
      expect(s.loggedDays, 0);
      expect(s.averageCalories, isNull);
    });

    test('macro split is the share of calories, not of grams', () {
      // 100 g protein = 400 kcal, 100 g carbs = 400 kcal, 100 g fat = 900.
      final s = summarize(
        [meal(DateTime(2026, 10, 11, 12), 1700, p: 100, c: 100, f: 100)],
        ProgressRange.week,
        today: today,
      );
      expect(s.macros!.fatShare, closeTo(900 / 1700, 1e-9));
      expect(s.macros!.proteinShare, closeTo(400 / 1700, 1e-9));
      expect(s.macros!.proteinGrams, 100);
    });

    test('no macros means no split rather than a zero split', () {
      final s = summarize(
        [meal(DateTime(2026, 10, 11, 12), 500)],
        ProgressRange.week,
        today: today,
      );
      expect(s.macros, isNull);
    });
  });

  test('all time starts at the earliest meal or weigh-in', () {
    final start = rangeStart(
      ProgressRange.all,
      today: today,
      meals: [meal(DateTime(2026, 8, 3, 12), 500)],
      weights: [WeightEntry(day: DateTime(2026, 7, 20), weightKg: 70)],
    );
    expect(start, DateTime(2026, 7, 20));
  });

  test('weight entries key on the calendar day', () {
    final e = WeightEntry(day: DateTime(2026, 3, 4, 23, 59), weightKg: 70.4);
    expect(e.key, '2026-03-04');
    expect(WeightEntry.tryFromJson(e.toJson())?.day, DateTime(2026, 3, 4));
    expect(WeightEntry.parseDay('2026-13-x'), isNull);
  });
}
