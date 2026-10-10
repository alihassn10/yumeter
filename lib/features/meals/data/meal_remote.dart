import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../domain/meal_entry.dart';

/// The account's copy of the meal log.
abstract interface class MealRemote {
  /// Every meal on the account. Row-level security limits it to the caller.
  Future<List<MealEntry>> fetchAll();

  Future<void> upsert(List<MealEntry> entries);

  Future<void> delete(List<String> ids);
}

class SupabaseMealRemote implements MealRemote {
  SupabaseMealRemote(this._client);

  final SupabaseClient _client;

  /// PostgREST returns at most this many rows per request.
  static const _page = 1000;

  @override
  Future<List<MealEntry>> fetchAll() async {
    final entries = <MealEntry>[];
    for (var from = 0; ; from += _page) {
      final rows = await _client
          .from('meals')
          .select()
          .order('logged_at')
          .order('id')
          .range(from, from + _page - 1);
      entries.addAll([for (final row in rows) ?mealFromRow(row)]);
      if (rows.length < _page) return entries;
    }
  }

  @override
  Future<void> upsert(List<MealEntry> entries) async {
    if (entries.isEmpty) return;
    await _client.from('meals').upsert([for (final e in entries) mealToRow(e)]);
  }

  @override
  Future<void> delete(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('meals').delete().inFilter('id', ids);
  }
}

/// The `meals` row for [entry]. `user_id` is left to the column default,
/// `auth.uid()`, so the app never claims an owner itself.
///
/// Times go over the wire in UTC: the device's local wall-clock time has no
/// offset and would otherwise be read as UTC and shift by the time zone.
///
/// The name is fitted to the table's 1–200 character check, because one row
/// the database rejects fails the whole batch and would stall the queue.
Map<String, dynamic> mealToRow(MealEntry entry) {
  final name = entry.name.trim();
  return {
    'id': entry.id,
    'logged_at': entry.loggedAt.toUtc().toIso8601String(),
    'meal_type': entry.type.name,
    'name': name.isEmpty
        ? 'Meal'
        : name.substring(0, name.length < 200 ? name.length : 200),
    'calories': entry.calories,
    'protein_grams': entry.proteinGrams,
    'carb_grams': entry.carbGrams,
    'fat_grams': entry.fatGrams,
    'source': entry.source.name,
  };
}

/// Reads a row through [MealEntry.tryFromJson], so a damaged row gets the same
/// skip-or-repair treatment as a damaged local record.
MealEntry? mealFromRow(Map<String, dynamic> row) {
  final loggedAt = DateTime.tryParse('${row['logged_at']}');
  if (loggedAt == null) return null;
  return MealEntry.tryFromJson({
    'id': row['id'],
    'loggedAt': loggedAt.toLocal().toIso8601String(),
    'type': row['meal_type'],
    'name': row['name'],
    'calories': row['calories'],
    'proteinGrams': row['protein_grams'],
    'carbGrams': row['carb_grams'],
    'fatGrams': row['fat_grams'],
    'source': row['source'],
  });
}

final mealRemoteProvider = Provider<MealRemote>(
  (ref) => SupabaseMealRemote(ref.watch(supabaseClientProvider)),
);
