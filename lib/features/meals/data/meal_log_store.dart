import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/meal_entry.dart';

/// On-device meal history.
///
/// A JSON list in shared preferences is enough for a single phone's log. It
/// gets replaced by Supabase plus a local cache once accounts exist, so it is
/// kept behind this class rather than read directly by widgets.
class MealLogStore {
  const MealLogStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'meals.v1';

  /// Damaged records are skipped one by one rather than failing the whole
  /// load, so a single bad write cannot hide a user's history.
  List<MealEntry> load() {
    final raw = _prefs.getString(_key);
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
        _key,
        jsonEncode([for (final e in entries) e.toJson()]),
      );
}

final mealLogStoreProvider = Provider<MealLogStore>(
  (ref) => MealLogStore(ref.watch(sharedPreferencesProvider)),
);
