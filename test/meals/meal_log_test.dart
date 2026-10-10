import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/utils/dates.dart';
import 'package:yumeter/features/meals/data/meal_log_store.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';

import '../support/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MealEntry', () {
    final entry = MealEntry(
      id: 'abc',
      loggedAt: DateTime(2026, 10, 10, 12, 30),
      type: MealType.lunch,
      name: 'Chicken wrap',
      calories: 540,
      proteinGrams: 38,
      carbGrams: 52,
      fatGrams: 18,
      source: MealSource.barcode,
    );

    test('round-trips through json', () {
      final back = MealEntry.tryFromJson(entry.toJson())!;
      expect(back.id, entry.id);
      expect(back.loggedAt, entry.loggedAt);
      expect(back.type, entry.type);
      expect(back.name, entry.name);
      expect(back.calories, entry.calories);
      expect(back.proteinGrams, entry.proteinGrams);
      expect(back.carbGrams, entry.carbGrams);
      expect(back.fatGrams, entry.fatGrams);
      expect(back.source, entry.source);
    });

    test('rejects a record missing what it cannot do without', () {
      expect(MealEntry.tryFromJson('nope'), isNull);
      expect(MealEntry.tryFromJson({'loggedAt': '2026-10-10', 'calories': 1}),
          isNull);
      expect(MealEntry.tryFromJson({'id': 'x', 'calories': 1}), isNull);
      expect(
        MealEntry.tryFromJson({'id': 'x', 'loggedAt': 'never', 'calories': 1}),
        isNull,
      );
    });

    test('fills in what it can do without', () {
      final sparse = MealEntry.tryFromJson({
        'id': 'x',
        'loggedAt': '2026-10-10T08:15:00.000',
        'calories': 300.6,
        'type': 'brunch_from_a_future_build',
      })!;
      expect(sparse.calories, 301);
      expect(sparse.name, 'Meal');
      expect(sparse.proteinGrams, 0);
      // An unknown meal type falls back to a guess from the time logged.
      expect(sparse.type, MealType.breakfast);
      expect(sparse.source, MealSource.quickAdd);
    });

    test('guesses the meal from the time of day', () {
      DateTime at(int hour) => DateTime(2026, 10, 10, hour);
      expect(MealType.forTime(at(7)), MealType.breakfast);
      expect(MealType.forTime(at(12)), MealType.lunch);
      expect(MealType.forTime(at(16)), MealType.snack);
      expect(MealType.forTime(at(19)), MealType.dinner);
      expect(MealType.forTime(at(23)), MealType.snack);
    });

    test('DayTotals sums every field', () {
      final totals = DayTotals.of([
        entry,
        entry.copyWith(id: 'def', calories: 100, proteinGrams: 2),
      ]);
      expect(totals.calories, 640);
      expect(totals.proteinGrams, 40);
      expect(totals.carbGrams, 104);
      expect(totals.fatGrams, 36);
    });
  });

  group('MealLogStore', () {
    test('skips damaged records instead of losing the whole log', () async {
      final prefs = await testPrefs();
      await prefs.setString(
        'meals.v1',
        '[{"id":"ok","loggedAt":"2026-10-10T12:00:00.000","calories":400},'
            '"garbage",'
            '{"id":"broken"}]',
      );
      final entries = MealLogStore(prefs).load();
      expect(entries.map((e) => e.id), ['ok']);
    });

    test('loads an unreadable log as empty', () async {
      final prefs = await testPrefs();
      await prefs.setString('meals.v1', '{not json');
      expect(MealLogStore(prefs).load(), isEmpty);
    });
  });

  group('MealLogController', () {
    test('persists what it adds', () async {
      final prefs = await testPrefs();
      final first = testContainer(prefs);
      addTearDown(first.dispose);

      await first.read(mealLogProvider.notifier).add(
            type: MealType.lunch,
            name: 'Salad',
            calories: 320,
            loggedAt: DateTime(2026, 10, 10, 13),
          );

      // A fresh container stands in for an app relaunch.
      final second = testContainer(prefs);
      addTearDown(second.dispose);
      expect(second.read(mealLogProvider).single.name, 'Salad');
    });

    test('keeps entries in time order whatever order they arrive in', () async {
      final container = testContainer(await testPrefs());
      addTearDown(container.dispose);
      final log = container.read(mealLogProvider.notifier);

      await log.add(
        type: MealType.dinner,
        name: 'Late',
        calories: 1,
        loggedAt: DateTime(2026, 10, 10, 20),
      );
      await log.add(
        type: MealType.breakfast,
        name: 'Early',
        calories: 1,
        loggedAt: DateTime(2026, 10, 10, 8),
      );

      expect(container.read(mealLogProvider).map((e) => e.name),
          ['Early', 'Late']);
    });

    test('remove and restore put an entry back exactly', () async {
      final container = testContainer(await testPrefs());
      addTearDown(container.dispose);
      final log = container.read(mealLogProvider.notifier);

      final entry = await log.add(
        type: MealType.snack,
        name: 'Apple',
        calories: 95,
        loggedAt: DateTime(2026, 10, 10, 16),
      );
      await log.remove(entry.id);
      expect(container.read(mealLogProvider), isEmpty);

      await log.restore(entry);
      await log.restore(entry); // A double tap on Undo must not duplicate.
      final restored = container.read(mealLogProvider).single;
      expect(restored.id, entry.id);
      expect(restored.loggedAt, entry.loggedAt);
    });

    test('relog copies the meal with a new id, time and type', () async {
      final container = testContainer(await testPrefs());
      addTearDown(container.dispose);
      final log = container.read(mealLogProvider.notifier);

      final original = await log.add(
        type: MealType.breakfast,
        name: 'Oats',
        calories: 380,
        proteinGrams: 14,
        loggedAt: DateTime(2026, 10, 9, 8),
      );
      final copy = await log.relog(
        original,
        type: MealType.snack,
        loggedAt: DateTime(2026, 10, 10, 15),
      );

      expect(copy.id, isNot(original.id));
      expect(copy.type, MealType.snack);
      expect(copy.calories, 380);
      expect(copy.proteinGrams, 14);
      expect(container.read(mealLogProvider), hasLength(2));
    });
  });

  group('selected day', () {
    test('shows only meals from that day', () async {
      final container = testContainer(await testPrefs());
      addTearDown(container.dispose);
      final log = container.read(mealLogProvider.notifier);
      final today = Dates.dateOnly(DateTime.now());
      final yesterday = Dates.addDays(today, -1);

      await log.add(
        type: MealType.lunch,
        name: 'Today lunch',
        calories: 500,
        loggedAt: logTimeFor(today),
      );
      await log.add(
        type: MealType.lunch,
        name: 'Yesterday lunch',
        calories: 700,
        loggedAt: logTimeFor(yesterday),
      );

      expect(container.read(dayMealsProvider).single.name, 'Today lunch');
      expect(container.read(dayTotalsProvider).calories, 500);

      container.read(selectedDayProvider.notifier).select(yesterday);
      expect(container.read(dayMealsProvider).single.name, 'Yesterday lunch');
      expect(container.read(dayTotalsProvider).calories, 700);
    });

    test('refuses a future day', () async {
      final container = testContainer(await testPrefs());
      addTearDown(container.dispose);

      container
          .read(selectedDayProvider.notifier)
          .select(DateTime.now().add(const Duration(days: 3)));
      expect(
        container.read(selectedDayProvider),
        Dates.dateOnly(DateTime.now()),
      );
    });

    test('logTimeFor keeps the time of day on the chosen date', () {
      expect(
        logTimeFor(
          DateTime(2026, 10, 5),
          now: DateTime(2026, 10, 10, 14, 30, 15),
        ),
        DateTime(2026, 10, 5, 14, 30, 15),
      );
    });
  });

  group('streak', () {
    final today = DateTime(2026, 10, 10);
    Set<DateTime> days(List<int> daysAgo) =>
        {for (final d in daysAgo) Dates.addDays(today, -d)};

    test('is zero with nothing logged', () {
      expect(currentStreak({}, today: today), 0);
    });

    test('counts consecutive days ending today', () {
      expect(currentStreak(days([0, 1, 2]), today: today), 3);
    });

    test('an empty today does not break it — the day is not over', () {
      expect(currentStreak(days([1, 2]), today: today), 2);
    });

    test('stops at the first gap', () {
      expect(currentStreak(days([0, 2, 3]), today: today), 1);
    });

    test('is zero once yesterday was missed too', () {
      expect(currentStreak(days([2, 3, 4]), today: today), 0);
    });
  });

  test('recent meals are distinct and newest first', () async {
    final container = testContainer(await testPrefs());
    addTearDown(container.dispose);
    final log = container.read(mealLogProvider.notifier);

    Future<void> add(String name, int kcal, int hour) => log.add(
          type: MealType.snack,
          name: name,
          calories: kcal,
          loggedAt: DateTime(2026, 10, 10, hour),
        );

    await add('Oats', 380, 8);
    await add('oats', 380, 9); // Same meal, different capitalisation.
    await add('Eggs', 200, 10);
    await add('Oats', 450, 11); // Bigger bowl, so a different meal.

    expect(
      container.read(recentMealsProvider).map((e) => '${e.name} ${e.calories}'),
      ['Oats 450', 'Eggs 200', 'oats 380'],
    );
  });
}
