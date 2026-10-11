import 'package:flutter/foundation.dart';
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

  /// Deletes the rows, then their photos. Storage objects cannot be removed
  /// from SQL, so the photo goes here, using the paths the delete returns.
  @override
  Future<void> delete(List<String> ids) async {
    if (ids.isEmpty) return;
    final deleted = await _client
        .from('meals')
        .delete()
        .inFilter('id', ids)
        .select('photo_path');
    final photos = [
      for (final row in deleted)
        if (row['photo_path'] case final String path) path,
    ];
    if (photos.isEmpty) return;
    try {
      await _client.storage.from(mealPhotosBucket).remove(photos);
    } on Exception catch (e) {
      // The meal is gone either way; a stray photo is only wasted storage
      // and must not hold up the rest of the queue.
      debugPrint('Could not remove meal photos $photos: $e');
    }
  }
}

/// Private bucket of meal photos, one folder per user id.
const mealPhotosBucket = 'meal-photos';

/// The `meals` row for [entry]. `user_id` is left to the column default,
/// `auth.uid()`, so the app never claims an owner itself.
///
/// Times go over the wire in UTC: the device's local wall-clock time has no
/// offset and would otherwise be read as UTC and shift by the time zone.
///
/// Every value is fitted to the table's checks (name 1–200 characters,
/// calories up to 20,000, macros up to 2,000 g), because one row the database
/// rejects fails the whole batch and would stall the queue.
Map<String, dynamic> mealToRow(MealEntry entry) {
  final name = entry.name.trim();
  int fit(int value, int max) => value.clamp(0, max);
  return {
    'id': entry.id,
    'logged_at': entry.loggedAt.toUtc().toIso8601String(),
    'meal_type': entry.type.name,
    'name': name.isEmpty
        ? 'Meal'
        : name.substring(0, name.length < 200 ? name.length : 200),
    'calories': fit(entry.calories, 20000),
    'protein_grams': fit(entry.proteinGrams, 2000),
    'carb_grams': fit(entry.carbGrams, 2000),
    'fat_grams': fit(entry.fatGrams, 2000),
    'source': entry.source.name,
    'photo_path': entry.photoPath,
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
    'photoPath': row['photo_path'],
  });
}

final mealRemoteProvider = Provider<MealRemote>(
  (ref) => SupabaseMealRemote(ref.watch(supabaseClientProvider)),
);
