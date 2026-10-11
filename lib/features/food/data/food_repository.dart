import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/food_product.dart';

/// Why a food lookup gave no answer.
enum FoodLookupFailure { offline, busy, failed }

class FoodLookupException implements Exception {
  const FoodLookupException(this.reason);

  final FoodLookupFailure reason;

  @override
  String toString() => 'FoodLookupException(${reason.name})';
}

/// Packaged-food data by name or barcode.
abstract interface class FoodRepository {
  Future<List<FoodProduct>> search(String query);

  /// Null when the barcode is not in the database.
  Future<FoodProduct?> byBarcode(String code);
}

/// Open Food Facts, the open food database.
///
/// Its limits are per device IP: 10 searches and 15 product reads a minute,
/// and search-as-you-type is not allowed. So searches run only when the user
/// submits, and both lookups are cached for the session.
class OpenFoodFactsRepository implements FoodRepository {
  OpenFoodFactsRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final _searches = <String, List<FoodProduct>>{};
  final _barcodes = <String, FoodProduct?>{};

  // Open Food Facts asks every app to identify itself as
  // "AppName/Version (contact)". Release builds pass the support address
  // with --dart-define=SUPPORT_EMAIL=... (docs/production.md).
  static const _contact = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'development build',
  );
  static const _userAgent = 'Yumeter/1.0 ($_contact)';
  static const _timeout = Duration(seconds: 12);

  static const _fields = 'code,product_name,brands,quantity,serving_size,'
      'serving_quantity,nutriments,image_front_small_url';

  @override
  Future<List<FoodProduct>> search(String query) async {
    final key = query.trim().toLowerCase();
    if (key.length < 2) return const [];
    if (_searches[key] case final cached?) return cached;

    final json = await _get(Uri.https('search.openfoodfacts.org', '/search', {
      'q': key,
      'page_size': '25',
      'fields': _fields,
    }));
    final hits = json['hits'];
    final products = [
      if (hits is List)
        for (final hit in hits)
          if (hit is Map<String, dynamic>) ?FoodProduct.fromOpenFoodFacts(hit),
    ];
    return _searches[key] = products;
  }

  @override
  Future<FoodProduct?> byBarcode(String code) async {
    if (_barcodes.containsKey(code)) return _barcodes[code];
    final json = await _get(Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code',
      {'fields': _fields},
    ));
    final product = json['status'] == 1 && json['product'] is Map
        ? FoodProduct.fromOpenFoodFacts({
            ...json['product'] as Map<String, dynamic>,
            'code': code,
          })
        : null;
    return _barcodes[code] = product;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw const FoodLookupException(FoodLookupFailure.offline);
    } on Exception {
      throw const FoodLookupException(FoodLookupFailure.offline);
    }

    // A missing barcode is a 404 with a JSON body saying so.
    if (res.statusCode == 404) return {'status': 0};
    if (res.statusCode == 429 || res.statusCode == 503) {
      throw const FoodLookupException(FoodLookupFailure.busy);
    }
    if (res.statusCode != 200) {
      throw const FoodLookupException(FoodLookupFailure.failed);
    }
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) return body;
    } on FormatException {
      // Falls through to failed.
    }
    throw const FoodLookupException(FoodLookupFailure.failed);
  }
}

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => OpenFoodFactsRepository(),
);
