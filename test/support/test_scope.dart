import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumeter/core/storage/preferences.dart';
import 'package:yumeter/core/storage/profile_remote.dart';
import 'package:yumeter/features/auth/data/account_remote.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/meals/data/meal_remote.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

import 'fakes.dart';

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
Future<SharedPreferences> testPrefs({
  OnboardingAnswers? profile,
  Map<String, Object> extra = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    if (profile != null) 'profile.answers': jsonEncode(profile.toJson()),
    ...extra,
  });
  return SharedPreferences.getInstance();
}

/// Overrides that keep every test off the network: signed out unless [auth]
/// says otherwise, with in-memory stand-ins for the account's data.
List<Override> testOverrides(
  SharedPreferences prefs, {
  FakeAuthRepository? auth,
  FakeMealRemote? meals,
  FakeProfileRemote? profiles,
  FakeAccountRemote? account,
}) =>
    [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      mealRemoteProvider.overrideWithValue(meals ?? FakeMealRemote()),
      profileRemoteProvider.overrideWithValue(profiles ?? FakeProfileRemote()),
      accountRemoteProvider.overrideWithValue(account ?? FakeAccountRemote()),
    ];

ProviderContainer testContainer(
  SharedPreferences prefs, {
  FakeAuthRepository? auth,
  FakeMealRemote? meals,
  FakeProfileRemote? profiles,
  FakeAccountRemote? account,
}) =>
    ProviderContainer(
      overrides: testOverrides(
        prefs,
        auth: auth,
        meals: meals,
        profiles: profiles,
        account: account,
      ),
    );
