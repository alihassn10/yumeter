/// One food the photo analysis found, as the user may have edited it.
class DraftItem {
  const DraftItem({
    required this.name,
    this.portion = '',
    required this.calories,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
  });

  final String name;

  /// A human-readable amount such as "1 cup". Empty when unknown.
  final String portion;

  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  /// The same food at [factor] times the portion, e.g. 2 for a double helping.
  /// Every figure scales together so the macros stay consistent.
  DraftItem scaled(double factor) {
    int scale(int v) => (v * factor).round();
    return DraftItem(
      name: name,
      portion: _scaledPortion(factor),
      calories: scale(calories),
      proteinGrams: scale(proteinGrams),
      carbGrams: scale(carbGrams),
      fatGrams: scale(fatGrams),
    );
  }

  String _scaledPortion(double factor) {
    if (factor == 1) return portion;
    final times = factor == factor.roundToDouble()
        ? factor.toInt().toString()
        : factor.toString();
    return portion.isEmpty ? '$times×' : '$times × $portion';
  }

  DraftItem copyWith({
    String? name,
    String? portion,
    int? calories,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
  }) {
    return DraftItem(
      name: name ?? this.name,
      portion: portion ?? this.portion,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbGrams: carbGrams ?? this.carbGrams,
      fatGrams: fatGrams ?? this.fatGrams,
    );
  }
}

/// A photo estimate the user reviews before it becomes a logged meal.
///
/// Totals are always the sum of the items, so editing or removing a food
/// updates the meal and the two can never disagree.
class MealDraft {
  const MealDraft({required this.name, required this.items});

  /// Reads the `analyze-meal` response, tolerating missing or odd fields so a
  /// partial answer still gives the user something to correct.
  factory MealDraft.fromAnalysis(Map<String, dynamic> json) {
    int n(Object? v) => v is num && v.isFinite && v > 0 ? v.round() : 0;
    String s(Object? v) => v is String ? v.trim() : '';

    final rawItems = json['items'];
    final items = [
      if (rawItems is List)
        for (final raw in rawItems)
          if (raw is Map<String, dynamic>)
            DraftItem(
              name: s(raw['name']).isEmpty ? 'Item' : s(raw['name']),
              portion: s(raw['portion']),
              calories: n(raw['calories']),
              proteinGrams: n(raw['protein_grams']),
              carbGrams: n(raw['carb_grams']),
              fatGrams: n(raw['fat_grams']),
            ),
    ];
    final name = s(json['name']);
    return MealDraft(name: name.isEmpty ? 'Meal' : name, items: items);
  }

  final String name;
  final List<DraftItem> items;

  int get calories => items.fold(0, (sum, i) => sum + i.calories);
  int get proteinGrams => items.fold(0, (sum, i) => sum + i.proteinGrams);
  int get carbGrams => items.fold(0, (sum, i) => sum + i.carbGrams);
  int get fatGrams => items.fold(0, (sum, i) => sum + i.fatGrams);

  /// A meal needs at least one food to be worth logging.
  bool get canSave => items.isNotEmpty;

  MealDraft withName(String value) {
    final trimmed = value.trim();
    return MealDraft(name: trimmed.isEmpty ? name : trimmed, items: items);
  }

  MealDraft withItem(int index, DraftItem item) =>
      MealDraft(name: name, items: [...items]..[index] = item);

  MealDraft withoutItem(int index) =>
      MealDraft(name: name, items: [...items]..removeAt(index));

  MealDraft withAddedItem(DraftItem item) =>
      MealDraft(name: name, items: [...items, item]);
}
