import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/pending_queue.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/supabase/supabase_config.dart';
import '../domain/weight_entry.dart';

/// The on-device weight history and its queue of unsynced changes, keyed by
/// day. Works the same way as the meal log: local first, synced behind.
class WeightLogStore {
  WeightLogStore(this._prefs) : queue = PendingQueue(_prefs, 'weights.pending.v1');

  final SharedPreferences _prefs;
  final PendingQueue queue;

  static const _entriesKey = 'weights.v1';

  List<WeightEntry> load() {
    final raw = _prefs.getString(_entriesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?WeightEntry.tryFromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<WeightEntry> entries) => _prefs.setString(
        _entriesKey,
        jsonEncode([for (final e in entries) e.toJson()]),
      );

  Future<void> clear() async {
    await _prefs.remove(_entriesKey);
    await queue.clear();
  }
}

final weightLogStoreProvider = Provider<WeightLogStore>(
  (ref) => WeightLogStore(ref.watch(sharedPreferencesProvider)),
);

/// The account's copy of the weight history.
abstract interface class WeightRemote {
  Future<List<WeightEntry>> fetchAll();

  Future<void> upsert(List<WeightEntry> entries);

  /// Deletes by day key (`yyyy-mm-dd`).
  Future<void> delete(List<String> days);
}

class SupabaseWeightRemote implements WeightRemote {
  SupabaseWeightRemote(this._client);

  final SupabaseClient _client;

  static const _page = 1000;

  @override
  Future<List<WeightEntry>> fetchAll() async {
    final entries = <WeightEntry>[];
    for (var from = 0;; from += _page) {
      final rows = await _client
          .from('weight_logs')
          .select('logged_on, weight_kg')
          .order('logged_on')
          .range(from, from + _page - 1);
      entries.addAll([for (final row in rows) ?weightFromRow(row)]);
      if (rows.length < _page) return entries;
    }
  }

  @override
  Future<void> upsert(List<WeightEntry> entries) async {
    if (entries.isEmpty) return;
    // Conflicts on the day key, so a second weigh-in replaces the first.
    await _client.from('weight_logs').upsert(
      [for (final e in entries) weightToRow(e)],
      onConflict: 'user_id,logged_on',
    );
  }

  @override
  Future<void> delete(List<String> days) async {
    if (days.isEmpty) return;
    await _client.from('weight_logs').delete().inFilter('logged_on', days);
  }
}

/// `user_id` comes from the column default, `auth.uid()`. The weight is
/// fitted to the table's 20–400 kg check so one bad value cannot stall the
/// queue.
Map<String, dynamic> weightToRow(WeightEntry e) => {
      'logged_on': e.key,
      'weight_kg': (e.weightKg.clamp(20, 400) * 10).round() / 10,
    };

WeightEntry? weightFromRow(Map<String, dynamic> row) {
  final day = WeightEntry.parseDay(row['logged_on']);
  final kg = row['weight_kg'];
  if (day == null || kg is! num) return null;
  return WeightEntry(day: day, weightKg: kg.toDouble());
}

final weightRemoteProvider = Provider<WeightRemote>(
  (ref) => SupabaseWeightRemote(ref.watch(supabaseClientProvider)),
);
