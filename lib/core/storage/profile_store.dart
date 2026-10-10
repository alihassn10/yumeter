import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/domain/onboarding_answers.dart';
import 'preferences.dart';

/// Local persistence for the user's profile.
///
/// Only the onboarding answers are stored; the plan is derived from them on
/// read, so a change to the calorie formula reaches existing users instead of
/// leaving them on a stale target.
class ProfileStore {
  const ProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const _answersKey = 'profile.answers';
  static const _pendingKey = 'profile.pending';

  Future<void> save(OnboardingAnswers answers) =>
      _prefs.setString(_answersKey, jsonEncode(answers.toJson()));

  /// True while the stored answers have not reached the account yet.
  bool get pending => _prefs.getBool(_pendingKey) ?? false;

  Future<void> setPending(bool value) => _prefs.setBool(_pendingKey, value);

  /// Returns null when nothing is stored, or when the stored value cannot be
  /// read — a corrupt profile should send the user through onboarding again
  /// rather than crash the app on launch.
  OnboardingAnswers? load() {
    final raw = _prefs.getString(_answersKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return OnboardingAnswers.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_answersKey);
    await _prefs.remove(_pendingKey);
  }
}

final profileStoreProvider = Provider<ProfileStore>(
  (ref) => ProfileStore(ref.watch(sharedPreferencesProvider)),
);

/// The stored profile at launch. Null means onboarding has not been completed.
final storedProfileProvider = Provider<OnboardingAnswers?>(
  (ref) => ref.watch(profileStoreProvider).load(),
);
