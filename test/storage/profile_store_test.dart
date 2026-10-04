import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumeter/core/storage/profile_store.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileStore store;

  Future<void> buildStore([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    store = ProfileStore(await SharedPreferences.getInstance());
  }

  setUp(() => buildStore());

  final sample = OnboardingAnswers(
    sex: Sex.female,
    birthDate: DateTime(1996, 3, 12),
    heightCm: 168,
    weightKg: 64.4,
    activityLevel: ActivityLevel.veryActive,
    goal: WeightGoal.lose,
    targetWeightKg: 58,
    paceKgPerWeek: 0.35,
    dietType: DietType.highProtein,
    units: UnitSystem.imperial,
  );

  test('round-trips every answer', () async {
    await store.save(sample);
    final loaded = store.load()!;

    expect(loaded.sex, sample.sex);
    expect(loaded.birthDate, sample.birthDate);
    expect(loaded.heightCm, sample.heightCm);
    expect(loaded.weightKg, sample.weightKg);
    expect(loaded.activityLevel, sample.activityLevel);
    expect(loaded.goal, sample.goal);
    expect(loaded.targetWeightKg, sample.targetWeightKg);
    expect(loaded.paceKgPerWeek, sample.paceKgPerWeek);
    expect(loaded.dietType, sample.dietType);
    expect(loaded.units, sample.units);
  });

  test('is null before anything is saved', () {
    expect(store.load(), isNull);
  });

  test('clearing removes the profile', () async {
    await store.save(sample);
    await store.clear();
    expect(store.load(), isNull);
  });

  test('a corrupt profile loads as null instead of throwing', () async {
    await buildStore({'profile.answers': 'not json at all'});
    expect(store.load(), isNull);
  });

  test('a profile that is valid json but not an object loads as null',
      () async {
    await buildStore({'profile.answers': '[1,2,3]'});
    expect(store.load(), isNull);
  });

  group('forward compatibility', () {
    test('an unknown enum name falls back rather than throwing', () {
      final answers = OnboardingAnswers.fromJson({
        'sex': 'nonbinary_from_a_future_build',
        'dietType': 'carnivore_from_a_future_build',
        'units': 'furlongs',
      });

      expect(answers.sex, isNull);
      expect(answers.dietType, DietType.balanced);
      expect(answers.units, UnitSystem.metric);
    });

    test('missing fields take their defaults', () {
      final answers = OnboardingAnswers.fromJson(const {});
      expect(answers.paceKgPerWeek, 0.5);
      expect(answers.weightKg, isNull);
      expect(answers.birthDate, isNull);
    });

    test('an unparseable date loads as null', () {
      final answers = OnboardingAnswers.fromJson(const {
        'birthDate': 'the third of never',
      });
      expect(answers.birthDate, isNull);
    });

    test('integer measurements survive json round-tripping as doubles', () {
      final answers = OnboardingAnswers.fromJson(const {
        'heightCm': 170,
        'weightKg': 70,
      });
      expect(answers.heightCm, 170.0);
      expect(answers.weightKg, 70.0);
    });
  });
}
