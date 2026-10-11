import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/dates.dart';
import '../../auth/data/auth_repository.dart';
import '../data/meal_log_store.dart';
import '../data/meal_remote.dart';
import '../domain/meal_entry.dart';

/// Every logged meal, oldest first.
///
/// Local first: every change lands on the phone immediately and is queued for
/// the account, then pushed in the background. A failed push leaves the queue
/// in place for the next attempt, so logging offline loses nothing.
class MealLogController extends Notifier<List<MealEntry>> {
  static const _uuid = Uuid();

  /// Sync work runs one task at a time, in order.
  Future<void> _queue = Future.value();

  MealLogStore get _store => ref.read(mealLogStoreProvider);

  @override
  List<MealEntry> build() {
    final entries = _sorted(ref.watch(mealLogStoreProvider).load());
    if (ref.read(currentUserProvider) != null) {
      // After the first frame's state is set, not during build.
      Future.microtask(sync);
    }
    return entries;
  }

  List<MealEntry> _sorted(Iterable<MealEntry> entries) =>
      [...entries]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  Future<void> _commit(
    List<MealEntry> next,
    Map<String, PendingOp> changes,
  ) async {
    final store = _store;
    state = _sorted(next);
    await store.save(state);
    await store.markPending(changes);
    unawaited(_enqueue(_push));
  }

  /// Sends queued changes, then brings in anything changed on another device.
  /// Called on launch, on sign-in and when the app returns to the foreground.
  Future<void> sync() => _enqueue(() async {
        await _push();
        await _pull();
      });

  /// Number of changes on this phone the account has not received yet.
  int get unsyncedCount => _store.loadPending().length;

  Future<void> _enqueue(Future<void> Function() task) {
    return _queue = _queue.then((_) async {
      if (!ref.mounted || ref.read(currentUserProvider) == null) return;
      try {
        await task();
      } on Exception catch (e) {
        // Offline or a server error: the queue stays put for the next try.
        debugPrint('Meal sync deferred: $e');
      }
    });
  }

  Future<void> _push() async {
    final sent = _store.loadPending();
    if (sent.isEmpty) return;

    final remote = ref.read(mealRemoteProvider);
    final byId = {for (final e in state) e.id: e};
    await remote.upsert([
      for (final MapEntry(:key, :value) in sent.entries)
        if (value.op == PendingOp.upsert) ?byId[key],
    ]);
    await remote.delete([
      for (final MapEntry(:key, :value) in sent.entries)
        if (value.op == PendingOp.delete) key,
    ]);
    if (!ref.mounted) return;

    // Clear only what was sent; an edit made mid-push keeps its newer stamp.
    final now = _store.loadPending()
      ..removeWhere((id, change) => sent[id]?.stamp == change.stamp);
    await _store.savePending(now);
  }

  Future<void> _pull() async {
    if (!ref.mounted) return;
    final userId = ref.read(currentUserProvider)?.id;
    final remote = await ref.read(mealRemoteProvider).fetchAll();
    // Signed out or switched account while the request was out.
    if (!ref.mounted || ref.read(currentUserProvider)?.id != userId) return;

    // The account wins, except for changes still waiting to go up.
    final local = {for (final e in state) e.id: e};
    final merged = {for (final e in remote) e.id: e};
    _store.loadPending().forEach((id, change) {
      if (change.op == PendingOp.delete) {
        merged.remove(id);
      } else if (local[id] case final entry?) {
        merged[id] = entry;
      }
    });

    state = _sorted(merged.values);
    await _store.save(state);
  }

  /// Logs a new meal. [id] is for a photo meal, whose photo was uploaded under
  /// the meal's id before the meal existed; otherwise one is generated.
  Future<MealEntry> add({
    String? id,
    required MealType type,
    required String name,
    required int calories,
    required DateTime loggedAt,
    int proteinGrams = 0,
    int carbGrams = 0,
    int fatGrams = 0,
    MealSource source = MealSource.quickAdd,
    String? photoPath,
  }) async {
    final entry = MealEntry(
      id: id ?? _uuid.v4(),
      loggedAt: loggedAt,
      type: type,
      name: name,
      calories: calories,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      source: source,
      photoPath: photoPath,
    );
    await _commit([...state, entry], {entry.id: PendingOp.upsert});
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

  Future<void> remove(String id) => _commit(
        [for (final e in state) if (e.id != id) e],
        {id: PendingOp.delete},
      );

  /// Saves an edited meal under its existing id.
  Future<void> update(MealEntry entry) async {
    if (!state.any((e) => e.id == entry.id)) return;
    await _commit(
      [for (final e in state) e.id == entry.id ? entry : e],
      {entry.id: PendingOp.upsert},
    );
  }

  /// Puts a removed entry back with its original id and time, for undo.
  Future<void> restore(MealEntry entry) async {
    if (state.any((e) => e.id == entry.id)) return;
    await _commit([...state, entry], {entry.id: PendingOp.upsert});
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
