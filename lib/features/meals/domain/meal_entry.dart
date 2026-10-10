import 'package:flutter/material.dart';

enum MealType {
  breakfast('Breakfast', Icons.wb_twilight_rounded),
  lunch('Lunch', Icons.wb_sunny_rounded),
  dinner('Dinner', Icons.dinner_dining_rounded),
  snack('Snack', Icons.cookie_rounded);

  const MealType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The meal someone is most likely logging at [time], used to preselect the
  /// meal chips so the common case is zero taps.
  static MealType forTime(DateTime time) => switch (time.hour) {
        < 11 => MealType.breakfast,
        < 15 => MealType.lunch,
        < 17 => MealType.snack,
        < 22 => MealType.dinner,
        _ => MealType.snack,
      };
}

/// How an entry was created. Kept so photo estimates can later be told apart
/// from figures the user typed or scanned off a label.
enum MealSource { photo, barcode, search, quickAdd }

class MealEntry {
  const MealEntry({
    required this.id,
    required this.loggedAt,
    required this.type,
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
    this.source = MealSource.quickAdd,
  });

  final String id;
  final DateTime loggedAt;
  final MealType type;
  final String name;
  final int calories;

  /// Zero when the user logged calories alone; quick add does not invent a
  /// macro split the user never entered.
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  final MealSource source;

  MealEntry copyWith({
    String? id,
    DateTime? loggedAt,
    MealType? type,
    String? name,
    int? calories,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
    MealSource? source,
  }) {
    return MealEntry(
      id: id ?? this.id,
      loggedAt: loggedAt ?? this.loggedAt,
      type: type ?? this.type,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbGrams: carbGrams ?? this.carbGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'loggedAt': loggedAt.toIso8601String(),
        'type': type.name,
        'name': name,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
        'fatGrams': fatGrams,
        'source': source.name,
      };

  /// Returns null for a record too damaged to show, so one bad entry cannot
  /// take the whole log down with it.
  static MealEntry? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;

    final id = json['id'];
    final loggedAt = json['loggedAt'];
    final calories = json['calories'];
    if (id is! String || loggedAt is! String || calories is! num) return null;

    final at = DateTime.tryParse(loggedAt);
    if (at == null) return null;

    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    int grams(Object? v) => v is num ? v.round() : 0;

    return MealEntry(
      id: id,
      loggedAt: at,
      type: byName(MealType.values, json['type'], MealType.forTime(at)),
      name: json['name'] is String ? json['name'] as String : 'Meal',
      calories: calories.round(),
      proteinGrams: grams(json['proteinGrams']),
      carbGrams: grams(json['carbGrams']),
      fatGrams: grams(json['fatGrams']),
      source: byName(MealSource.values, json['source'], MealSource.quickAdd),
    );
  }
}

/// Summed intake for a set of entries.
class DayTotals {
  const DayTotals({
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
  });

  factory DayTotals.of(Iterable<MealEntry> entries) {
    var calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final e in entries) {
      calories += e.calories;
      protein += e.proteinGrams;
      carbs += e.carbGrams;
      fat += e.fatGrams;
    }
    return DayTotals(
      calories: calories,
      proteinGrams: protein,
      carbGrams: carbs,
      fatGrams: fat,
    );
  }

  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
}
