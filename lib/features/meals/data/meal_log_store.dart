import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/meal_entry.dart';

/// What still has to reach the server for one meal.
enum PendingOp { upsert, delete }

/// A change made on this phone that the server has not confirmed yet.
///
/// [stamp] tells two changes to the same meal apart, so a push only clears
/// the change it actually sent and not a newer edit made while it was in
/// flight.
class PendingChange {
  const PendingChange(this.op, this.stamp);

  final PendingOp op;
  final int stamp;
}

/// The on-device copy of the meal log, plus the queue of changes waiting to
/// sync.
///
/// The app reads and writes here first so logging works offline and the
/// dashboard never waits on the network; the account copy is brought in line
/// in the background.
class MealLogStore {
  const MealLogStore(this._prefs);

  final SharedPreferences _prefs;

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

  /// Latest unsynced change per meal id. Only the newest intent matters: a
  /// meal added then deleted offline needs a delete, nothing else.
  Map<String, PendingChange> loadPending() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final pending = <String, PendingChange>{};
      decoded.forEach((id, value) {
        if (value is! Map<String, dynamic>) return;
        final op = PendingOp.values.asNameMap()[value['op']];
        final stamp = value['stamp'];
        if (op != null && stamp is int) pending[id] = PendingChange(op, stamp);
      });
      return pending;
    } on FormatException {
      return {};
    }
  }

  Future<void> savePending(Map<String, PendingChange> pending) =>
      _prefs.setString(
        _pendingKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in pending.entries)
            key: {'op': value.op.name, 'stamp': value.stamp},
        }),
      );

  /// Queues [ops] on top of whatever is already waiting.
  Future<void> markPending(Map<String, PendingOp> ops) {
    if (ops.isEmpty) return Future.value();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return savePending({
      ...loadPending(),
      for (final MapEntry(:key, :value) in ops.entries)
        key: PendingChange(value, stamp),
    });
  }

  /// Forgets the log and its queue, for sign-out or a different account.
  Future<void> clear() async {
    await _prefs.remove(_entriesKey);
    await _prefs.remove(_pendingKey);
  }
}

final mealLogStoreProvider = Provider<MealLogStore>(
  (ref) => MealLogStore(ref.watch(sharedPreferencesProvider)),
);
