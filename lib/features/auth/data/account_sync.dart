import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/storage/profile_remote.dart';
import '../../../core/storage/profile_store.dart';
import '../../meals/data/meal_log_store.dart';
import '../../meals/state/meal_log_controller.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../../onboarding/state/onboarding_controller.dart';
import 'account_remote.dart';
import 'auth_repository.dart';

/// Keeps the data on this phone tied to the account it belongs to.
///
/// Meals and the profile are read from the phone first and synced in the
/// background. This class decides what happens to that local copy when
/// someone signs in or out, and moves the profile between phone and account.
class AccountSync {
  AccountSync(this._ref);

  final Ref _ref;

  /// The user id the local data belongs to. Null means it was created before
  /// any sign-in on this phone.
  static const _ownerKey = 'account.owner';

  ProfileStore get _profiles => _ref.read(profileStoreProvider);
  MealLogStore get _meals => _ref.read(mealLogStoreProvider);

  /// Claims or replaces the local data for [user] and brings in the account's
  /// copy. Returns whether a profile exists, which decides between onboarding
  /// and the dashboard.
  Future<bool> signedIn(AuthUser user) async {
    _ref.read(currentUserProvider.notifier).refresh();

    final prefs = _ref.read(sharedPreferencesProvider);
    final owner = prefs.getString(_ownerKey);
    var adopting = false;

    if (owner != user.id) {
      if (owner == null) {
        // Logged before signing in: it is this person's, so keep it and queue
        // all of it for the account.
        await _meals.markPending({
          for (final e in _meals.load()) e.id: PendingOp.upsert,
        });
        adopting = true;
      } else {
        // Someone else's data on a shared phone.
        await _clearLocal();
      }
      await prefs.setString(_ownerKey, user.id);
    }

    _ref.invalidate(mealLogProvider);
    unawaited(_ref.read(mealLogProvider.notifier).sync());
    return restoreProfile(adopting: adopting);
  }

  /// Brings the profile in line with the account. Unsynced local answers go
  /// up; otherwise the account's copy wins. Offline, the phone's copy stands.
  ///
  /// When [adopting] pre-account answers, an existing account profile still
  /// wins: the account is the record, the phone only had a draft.
  Future<bool> restoreProfile({bool adopting = false}) async {
    final user = _ref.read(currentUserProvider);
    if (user != null) {
      try {
        if (_profiles.pending && !adopting) {
          await pushProfile();
        } else {
          final remote = await _ref.read(profileRemoteProvider).fetch(user.id);
          if (remote != null) {
            await _profiles.save(remote);
            await _profiles.setPending(false);
            _ref.invalidate(storedProfileProvider);
          } else if (_profiles.load() != null) {
            await _profiles.setPending(true);
            await pushProfile();
          }
        }
      } on Exception catch (e) {
        debugPrint('Profile sync deferred: $e');
      }
    }
    return _profiles.load() != null;
  }

  /// Saves the answers on the phone at once and sends them up when possible.
  Future<void> saveProfile(OnboardingAnswers answers) async {
    await _profiles.save(answers);
    await _profiles.setPending(true);
    _ref.invalidate(storedProfileProvider);
    unawaited(_tryPushProfile());
  }

  Future<void> pushProfile() async {
    final user = _ref.read(currentUserProvider);
    final answers = _profiles.load();
    if (user == null || answers == null || !_profiles.pending) return;

    final sent = jsonEncode(answers.toJson());
    await _ref.read(profileRemoteProvider).upsert(user.id, answers);
    // Answers edited while the request was out still need sending.
    if (jsonEncode(_profiles.load()?.toJson()) == sent) {
      await _profiles.setPending(false);
    }
  }

  Future<void> _tryPushProfile() async {
    try {
      await pushProfile();
    } on Exception catch (e) {
      debugPrint('Profile sync deferred: $e');
    }
  }

  /// Retries anything still waiting, e.g. when the app comes back online in
  /// the foreground.
  Future<void> syncAll() async {
    if (_ref.read(currentUserProvider) == null) return;
    await Future.wait([
      _ref.read(mealLogProvider.notifier).sync(),
      _tryPushProfile(),
    ]);
  }

  /// Changes on this phone the account does not have yet. Signing out drops
  /// them, so the UI warns first.
  int get unsyncedCount =>
      _meals.loadPending().length + (_profiles.pending ? 1 : 0);

  /// Deletes the account on the server, then clears this phone as a sign-out
  /// does. Throws [AccountDeletionException] and leaves everything in place
  /// if the server could not do it.
  Future<void> deleteAccount() async {
    await _ref.read(accountRemoteProvider).deleteAccount();
    // Nothing is left to sync to, so there is no point keeping the queue.
    await signOut();
  }

  /// Signs out and wipes this phone's copy, so the next person to sign in
  /// never sees it.
  Future<void> signOut() async {
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } on Exception catch (e) {
      // The session is dropped on the phone before the server is told, so an
      // offline sign-out has already happened here; finish clearing up.
      debugPrint('Sign-out could not reach the server: $e');
    }
    _ref.read(currentUserProvider.notifier).refresh();
    await _clearLocal();
    await _ref.read(sharedPreferencesProvider).remove(_ownerKey);
  }

  Future<void> _clearLocal() async {
    await _meals.clear();
    await _profiles.clear();
    _ref
      ..invalidate(mealLogProvider)
      ..invalidate(storedProfileProvider)
      // A half-finished quiz is the previous person's too.
      ..invalidate(onboardingControllerProvider);
  }
}

final accountSyncProvider = Provider<AccountSync>(AccountSync.new);
