import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/pending_queue.dart';
import '../../../core/storage/preferences.dart';
import '../domain/meal_entry.dart';

export '../../../core/storage/pending_queue.dart' show PendingChange, PendingOp;

/// The on-device copy of the meal log, plus the queue of changes waiting to
/// sync.
///
/// The app reads and writes here first so logging works offline and the
/// dashboard never waits on the network; the account copy is brought in line
/// in the background.
class MealLogStore {
  MealLogStore(this._prefs) : _queue = PendingQueue(_prefs, _pendingKey);

  final SharedPreferences _prefs;
  final PendingQueue _queue;

  static const _entriesKey = 'meals.v1';
  static const _pendingKey = 'meals.pending.v1';

  /// Damaged records are skipped one by one rather than failing the whole
  /// load, so a single bad write cannot hide a user's history.
  List<MealEntry> load() {
    final raw = _prefs.getString(_entriesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?MealEntry.tryFromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<MealEntry> entries) => _prefs.setString(
        _entriesKey,
        jsonEncode([for (final e in entries) e.toJson()]),
      );

  Map<String, PendingChange> loadPending() => _queue.load();

  Future<void> savePending(Map<String, PendingChange> pending) =>
      _queue.save(pending);

  Future<void> markPending(Map<String, PendingOp> ops) => _queue.mark(ops);

  /// Forgets the log and its queue, for sign-out or a different account.
  Future<void> clear() async {
    await _prefs.remove(_entriesKey);
    await _queue.clear();
  }
}

final mealLogStoreProvider = Provider<MealLogStore>(
  (ref) => MealLogStore(ref.watch(sharedPreferencesProvider)),
);
