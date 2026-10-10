import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumeter/core/storage/preferences.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

/// A completed profile, so plan-dependent screens have targets to show.
///
/// Female / 30 / 165 cm / 65 kg / moderately active / lose 0.5 kg a week /
/// balanced — which works out to 1574 kcal a day.
final sampleProfile = OnboardingAnswers(
  sex: Sex.female,
  birthDate: DateTime(DateTime.now().year - 30, 1, 1),
  heightCm: 165,
  weightKg: 65,
  activityLevel: ActivityLevel.moderate,
  goal: WeightGoal.lose,
  targetWeightKg: 60,
);

/// Fresh in-memory preferences, optionally pre-seeded with a profile.
Future<SharedPreferences> testPrefs({OnboardingAnswers? profile}) async {
  SharedPreferences.setMockInitialValues({
    if (profile != null) 'profile.answers': jsonEncode(profile.toJson()),
  });
  return SharedPreferences.getInstance();
}

ProviderContainer testContainer(SharedPreferences prefs) {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  return container;
}
