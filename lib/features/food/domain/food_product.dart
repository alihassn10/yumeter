/// A packaged food from Open Food Facts, with nutrition per 100 g.
///
/// Open Food Facts records liquids per 100 ml under the same keys; the app
/// treats a millilitre as a gram, close enough for most drinks.
class FoodProduct {
  const FoodProduct({
    required this.code,
    required this.name,
    this.brand,
    this.imageUrl,
    this.packageLabel,
    this.servingGrams,
    this.servingLabel,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbPer100g,
    required this.fatPer100g,
  });

  /// The barcode.
  final String code;
  final String name;
  final String? brand;
  final String? imageUrl;

  /// The pack size as printed, e.g. "400 g".
  final String? packageLabel;

  /// One serving in grams, when the label gives one.
  final double? servingGrams;

  /// The serving as printed, e.g. "1 pot (125 g)".
  final String? servingLabel;

  final double kcalPer100g;
  final double proteinPer100g;
  final double carbPer100g;
  final double fatPer100g;

  /// "Brand · Name" for the log, or just the name.
  String get displayName =>
      brand == null || name.toLowerCase().contains(brand!.toLowerCase())
          ? name
          : '$brand $name';

  /// Reads an Open Food Facts product, from either the product API or search.
  ///
  /// Returns null when there is no name or no energy figure: without energy
  /// there is nothing to log, and showing it would invite a 0 kcal entry.
  static FoodProduct? fromOpenFoodFacts(Map<String, dynamic> json) {
    final code = json['code'];
    final name = (json['product_name'] is String)
        ? (json['product_name'] as String).trim()
        : '';
    final n = json['nutriments'];
    if (code is! String || name.isEmpty || n is! Map<String, dynamic>) {
      return null;
    }

    double? num100(String key) {
      final v = n['${key}_100g'];
      return v is num && v.isFinite && v >= 0 ? v.toDouble() : null;
    }

    // Some products carry only kilojoules.
    final kcal = num100('energy-kcal') ??
        switch (num100('energy-kj') ?? num100('energy')) {
          final kj? => kj / 4.184,
          null => null,
        };
    if (kcal == null) return null;

    final brands = json['brands'];
    final brand = switch (brands) {
      final List<dynamic> list when list.isNotEmpty => '${list.first}',
      final String s when s.trim().isNotEmpty => s.split(',').first.trim(),
      _ => null,
    };

    final serving = json['serving_quantity'];
    final servingGrams = switch (serving) {
      final num v when v > 0 => v.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

    String? text(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;

    return FoodProduct(
      code: code,
      name: name,
      brand: brand,
      imageUrl: text(json['image_front_small_url']),
      packageLabel: text(json['quantity']),
      servingGrams: servingGrams != null && servingGrams > 0
          ? servingGrams
          : null,
      servingLabel: text(json['serving_size']),
      kcalPer100g: kcal,
      proteinPer100g: num100('proteins') ?? 0,
      carbPer100g: num100('carbohydrates') ?? 0,
      fatPer100g: num100('fat') ?? 0,
    );
  }
}

/// What a chosen amount of a product adds up to.
class Portion {
  const Portion(this.product, this.grams);

  final FoodProduct product;
  final double grams;

  double get _factor => grams / 100;

  int get calories => (product.kcalPer100g * _factor).round();
  int get proteinGrams => (product.proteinPer100g * _factor).round();
  int get carbGrams => (product.carbPer100g * _factor).round();
  int get fatGrams => (product.fatPer100g * _factor).round();
}
