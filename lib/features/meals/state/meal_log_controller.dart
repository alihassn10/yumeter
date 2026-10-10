import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/dates.dart';
import '../data/meal_log_store.dart';
import '../domain/meal_entry.dart';

/// Every logged meal, oldest first.
class MealLogController extends Notifier<List<MealEntry>> {
  static const _uuid = Uuid();

  @override
  List<MealEntry> build() => _sorted(ref.watch(mealLogStoreProvider).load());

  List<MealEntry> _sorted(Iterable<MealEntry> entries) =>
      [...entries]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  Future<void> _commit(List<MealEntry> next) async {
    state = _sorted(next);
    await ref.read(mealLogStoreProvider).save(state);
  }

  Future<MealEntry> add({
    required MealType type,
    required String name,
    required int calories,
    required DateTime loggedAt,
    int proteinGrams = 0,
    int carbGrams = 0,
    int fatGrams = 0,
    MealSource source = MealSource.quickAdd,
  }) async {
    final entry = MealEntry(
      id: _uuid.v4(),
      loggedAt: loggedAt,
      type: type,
      name: name,
      calories: calories,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      source: source,
    );
    await _commit([...state, entry]);
    return entry;
  }

  /// Logs a fresh copy of a past entry — the one-tap path for meals people
  /// eat over and over.
  Future<MealEntry> relog(
    MealEntry original, {
    required MealType type,
    required DateTime loggedAt,
  }) =>
      add(
        type: type,
        name: original.name,
        calories: original.calories,
        proteinGrams: original.proteinGrams,
        carbGrams: original.carbGrams,
        fatGrams: original.fatGrams,
        source: original.source,
        loggedAt: loggedAt,
      );

  Future<void> remove(String id) =>
      _commit([for (final e in state) if (e.id != id) e]);

  /// Puts a removed entry back with its original id and time, for undo.
  Future<void> restore(MealEntry entry) async {
    if (state.any((e) => e.id == entry.id)) return;
    await _commit([...state, entry]);
  }
}

final mealLogProvider = NotifierProvider<MealLogController, List<MealEntry>>(
  MealLogController.new,
);

/// The calendar day the dashboard is showing.
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => Dates.dateOnly(DateTime.now());

  /// Future days are refused: there is nothing to show and nothing should be
  /// logged against them.
  void select(DateTime day) {
    final today = Dates.dateOnly(DateTime.now());
    final picked = Dates.dateOnly(day);
    state = picked.isAfter(today) ? today : picked;
  }
}

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

/// When a meal logged from the dashboard should be timestamped: now, on the
/// day being viewed. Logging into yesterday keeps the current time of day so
/// entries still sort sensibly within it.
DateTime logTimeFor(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return DateTime(day.year, day.month, day.day, n.hour, n.minute, n.second);
}

final dayMealsProvider = Provider<List<MealEntry>>((ref) {
  final day = ref.watch(selectedDayProvider);
  return [
    for (final e in ref.watch(mealLogProvider))
      if (Dates.isSameDay(e.loggedAt, day)) e,
  ];
});

final dayTotalsProvider = Provider<DayTotals>(
  (ref) => DayTotals.of(ref.watch(dayMealsProvider)),
);

/// Every calendar day with at least one entry.
final loggedDaysProvider = Provider<Set<DateTime>>(
  (ref) => {
    for (final e in ref.watch(mealLogProvider)) Dates.dateOnly(e.loggedAt),
  },
);

/// Consecutive logged days ending today.
///
/// An empty today does not break the run — the day is not over — so the count
/// is taken from yesterday until something is logged.
int currentStreak(Set<DateTime> loggedDays, {DateTime? today}) {
  var day = Dates.dateOnly(today ?? DateTime.now());
  if (!loggedDays.contains(day)) day = Dates.addDays(day, -1);

  var count = 0;
  while (loggedDays.contains(day)) {
    count++;
    day = Dates.addDays(day, -1);
  }
  return count;
}

final streakProvider = Provider<int>(
  (ref) => currentStreak(ref.watch(loggedDaysProvider)),
);

/// Distinct recent meals for one-tap relogging, newest first.
final recentMealsProvider = Provider<List<MealEntry>>((ref) {
  final seen = <String>{};
  final recent = <MealEntry>[];
  for (final e in ref.watch(mealLogProvider).reversed) {
    // Same name and calories reads as the same meal to the person logging it.
    if (seen.add('${e.name.toLowerCase()}|${e.calories}')) recent.add(e);
    if (recent.length == 5) break;
  }
  return recent;
});
