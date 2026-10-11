import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/meals/data/meal_remote.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/scan/domain/meal_draft.dart';
import 'package:yumeter/features/scan/domain/picked_photo.dart';

void main() {
  const rice = DraftItem(
    name: 'Rice',
    portion: '1 cup',
    calories: 205,
    proteinGrams: 4,
    carbGrams: 45,
    fatGrams: 1,
  );
  const salmon = DraftItem(
    name: 'Salmon',
    portion: '150 g',
    calories: 310,
    proteinGrams: 34,
    carbGrams: 0,
    fatGrams: 18,
  );
  const draft = MealDraft(name: 'Salmon bowl', items: [rice, salmon]);

  group('MealDraft', () {
    test('totals are the sum of the foods', () {
      expect(draft.calories, 515);
      expect(draft.proteinGrams, 38);
      expect(draft.carbGrams, 45);
      expect(draft.fatGrams, 19);
    });

    test('editing or removing a food moves the totals with it', () {
      expect(draft.withoutItem(0).calories, 310);
      expect(draft.withItem(0, rice.copyWith(calories: 100)).calories, 410);
      expect(draft.withAddedItem(rice).calories, 720);
    });

    test('an empty meal cannot be logged', () {
      expect(draft.canSave, isTrue);
      expect(draft.withoutItem(0).withoutItem(0).canSave, isFalse);
    });

    test('a blank rename keeps the old name', () {
      expect(draft.withName('  ').name, 'Salmon bowl');
      expect(draft.withName(' Lunch bowl ').name, 'Lunch bowl');
    });

    test('reads the analyze-meal response', () {
      final parsed = MealDraft.fromAnalysis({
        'name': 'Salmon bowl',
        'calories': 515,
        'items': [
          {
            'name': 'Rice',
            'portion': '1 cup',
            'calories': 205,
            'protein_grams': 4,
            'carb_grams': 45,
            'fat_grams': 1,
          },
        ],
      });
      expect(parsed.name, 'Salmon bowl');
      expect(parsed.items.single.portion, '1 cup');
      expect(parsed.items.single.carbGrams, 45);
    });

    test('tolerates a damaged response instead of failing', () {
      final parsed = MealDraft.fromAnalysis({
        'items': [
          'not a map',
          {'calories': -40, 'protein_grams': 'lots', 'name': ''},
        ],
      });
      expect(parsed.name, 'Meal');
      expect(parsed.items.single.name, 'Item');
      expect(parsed.items.single.calories, 0);
      expect(parsed.items.single.proteinGrams, 0);
    });
  });

  group('DraftItem.scaled', () {
    test('scales every figure together', () {
      final twice = rice.scaled(2);
      expect(twice.calories, 410);
      expect(twice.proteinGrams, 8);
      expect(twice.carbGrams, 90);
      expect(twice.portion, '2 × 1 cup');
    });

    test('labels half portions without trailing zeros', () {
      expect(rice.scaled(0.5).portion, '0.5 × 1 cup');
      expect(rice.scaled(1).portion, '1 cup');
    });
  });

  group('photo meals in rows', () {
    final entry = MealEntry(
      id: 'abc',
      loggedAt: DateTime(2026, 10, 11, 13),
      type: MealType.lunch,
      name: 'Salmon bowl',
      calories: 515,
      source: MealSource.photo,
      photoPath: 'user-a/abc.jpg',
    );

    test('carry the photo path both ways', () {
      expect(mealToRow(entry)['photo_path'], 'user-a/abc.jpg');
      expect(mealFromRow(mealToRow(entry))?.photoPath, 'user-a/abc.jpg');
      expect(MealEntry.tryFromJson(entry.toJson())?.photoPath,
          'user-a/abc.jpg');
    });

    test('clamp figures to what the database accepts', () {
      final row = mealToRow(entry.copyWith(calories: 99999, fatGrams: 5000));
      expect(row['calories'], 20000);
      expect(row['fat_grams'], 2000);
    });
  });

  test('picked photos keep a known extension and default to jpg', () {
    expect(PickedPhoto.extensionOf('IMG_1.HEIC'), 'heic');
    expect(PickedPhoto.extensionOf('photo.png'), 'png');
    expect(PickedPhoto.extensionOf('weird.tiff'), 'jpg');
    expect(PickedPhoto.extensionOf('no_extension'), 'jpg');
  });
}
