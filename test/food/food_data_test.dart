import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yumeter/features/food/data/food_repository.dart';
import 'package:yumeter/features/food/domain/food_product.dart';

void main() {
  group('FoodProduct.fromOpenFoodFacts', () {
    test('reads a search hit, where brands is a list', () {
      final p = FoodProduct.fromOpenFoodFacts({
        'code': '0894700010137',
        'product_name': 'Nonfat Greek Yogurt',
        'brands': ['Chobani'],
        'quantity': '32 OZ',
        'nutriments': {
          'energy-kcal_100g': 52.9,
          'proteins_100g': 9.41,
          'carbohydrates_100g': 3.53,
          'fat_100g': 0,
        },
      })!;
      expect(p.brand, 'Chobani');
      expect(p.kcalPer100g, 52.9);
      expect(p.displayName, 'Chobani Nonfat Greek Yogurt');
      expect(p.servingGrams, isNull);
    });

    test('reads a product lookup, where brands is a comma list', () {
      final p = FoodProduct.fromOpenFoodFacts({
        'code': '3017624010701',
        'product_name': 'Nutella',
        'brands': 'Ferrero, Nutella',
        'serving_quantity': '15',
        'serving_size': '15 g',
        'nutriments': {'energy-kcal_100g': 539, 'fat_100g': 30.9},
      })!;
      expect(p.brand, 'Ferrero');
      expect(p.servingGrams, 15);
      expect(p.servingLabel, '15 g');
      // Missing macros read as zero rather than failing the product.
      expect(p.proteinPer100g, 0);
    });

    test('converts kilojoules when there is no kcal figure', () {
      final p = FoodProduct.fromOpenFoodFacts({
        'code': '1',
        'product_name': 'Crackers',
        'nutriments': {'energy-kj_100g': 1674},
      })!;
      expect(p.kcalPer100g, closeTo(400, 0.1));
    });

    test('skips products with no name or no energy', () {
      expect(
        FoodProduct.fromOpenFoodFacts({
          'code': '1',
          'product_name': '',
          'nutriments': {'energy-kcal_100g': 100},
        }),
        isNull,
      );
      expect(
        FoodProduct.fromOpenFoodFacts({
          'code': '1',
          'product_name': 'Mystery',
          'nutriments': {'proteins_100g': 5},
        }),
        isNull,
      );
    });

    test('does not repeat a brand already in the name', () {
      final p = FoodProduct.fromOpenFoodFacts({
        'code': '1',
        'product_name': 'Nutella hazelnut spread',
        'brands': 'Nutella',
        'nutriments': {'energy-kcal_100g': 539},
      })!;
      expect(p.displayName, 'Nutella hazelnut spread');
    });
  });

  test('a portion scales the per-100 g values', () {
    const p = FoodProduct(
      code: '1',
      name: 'Oats',
      kcalPer100g: 380,
      proteinPer100g: 13,
      carbPer100g: 60,
      fatPer100g: 7,
    );
    const portion = Portion(p, 40);
    expect(portion.calories, 152);
    expect(portion.proteinGrams, 5);
    expect(portion.carbGrams, 24);
    expect(portion.fatGrams, 3);
  });

  group('OpenFoodFactsRepository', () {
    final hit = {
      'code': '1',
      'product_name': 'Oats',
      'nutriments': {'energy-kcal_100g': 380},
    };

    test('searches once per query and sends an identifying User-Agent',
        () async {
      final requests = <http.Request>[];
      final repo = OpenFoodFactsRepository(
        client: MockClient((req) async {
          requests.add(req);
          return http.Response(jsonEncode({'hits': [hit]}), 200);
        }),
      );

      final first = await repo.search('Oats ');
      final second = await repo.search('oats');

      expect(first.single.name, 'Oats');
      expect(second.single.name, 'Oats');
      expect(requests, hasLength(1), reason: 'the repeat comes from cache');
      expect(requests.single.url.host, 'search.openfoodfacts.org');
      expect(requests.single.headers['User-Agent'], startsWith('Yumeter/'));
    });

    test('ignores queries too short to be useful', () async {
      var calls = 0;
      final repo = OpenFoodFactsRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(await repo.search('a'), isEmpty);
      expect(calls, 0);
    });

    test('an unknown barcode is null, not an error', () async {
      final repo = OpenFoodFactsRepository(
        client: MockClient((_) async => http.Response(
              jsonEncode({'status': 0, 'status_verbose': 'product not found'}),
              404,
            )),
      );
      expect(await repo.byBarcode('1234567890128'), isNull);
    });

    test('a known barcode becomes a product', () async {
      final repo = OpenFoodFactsRepository(
        client: MockClient((req) async {
          expect(req.url.path, '/api/v2/product/3017624010701');
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': 'Nutella',
                'nutriments': {'energy-kcal_100g': 539},
              },
            }),
            200,
          );
        }),
      );
      final p = await repo.byBarcode('3017624010701');
      expect(p?.code, '3017624010701');
    });

    test('rate limits read as busy and network errors as offline', () async {
      final busy = OpenFoodFactsRepository(
        client: MockClient((_) async => http.Response('', 429)),
      );
      await expectLater(
        busy.search('oats'),
        throwsA(isA<FoodLookupException>().having(
          (e) => e.reason,
          'reason',
          FoodLookupFailure.busy,
        )),
      );

      final offline = OpenFoodFactsRepository(
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      await expectLater(
        offline.byBarcode('1'),
        throwsA(isA<FoodLookupException>().having(
          (e) => e.reason,
          'reason',
          FoodLookupFailure.offline,
        )),
      );
    });
  });
}
