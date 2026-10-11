import 'dart:async';
import 'dart:typed_data';

import 'package:yumeter/core/storage/profile_remote.dart';
import 'package:yumeter/features/auth/data/account_remote.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/meals/data/meal_remote.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';
import 'package:yumeter/features/progress/data/weight_log_store.dart';
import 'package:yumeter/features/progress/domain/weight_entry.dart';
import 'package:yumeter/features/scan/data/meal_photo_service.dart';
import 'package:yumeter/features/scan/domain/meal_draft.dart';

const testUser = AuthUser(id: 'user-a', email: 'a@example.test');
const otherUser = AuthUser(id: 'user-b', email: 'b@example.test');

/// Signs in whoever [verifyCode] is asked about, as [signInAs].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.signInAs = testUser});

  AuthUser? user;
  AuthUser signInAs;

  /// Mimics Supabase offline: the session is dropped locally, then the call
  /// to revoke it on the server fails.
  bool offline = false;
  final _changes = StreamController<AuthUser?>.broadcast();
  final sentCodesTo = <String>[];

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> sendCode(String email) async => sentCodesTo.add(email);

  @override
  Future<AuthUser> verifyCode({
    required String email,
    required String code,
  }) async {
    if (code != '123456') throw const AuthFailure('That code did not work.');
    user = signInAs;
    _changes.add(user);
    return signInAs;
  }

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(null);
    if (offline) throw Exception('offline');
  }
}

/// An account's meals held in memory. Set [offline] to make every call fail
/// the way a dropped connection does.
class FakeMealRemote implements MealRemote {
  final rows = <String, MealEntry>{};
  bool offline = false;
  int upsertCalls = 0;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<List<MealEntry>> fetchAll() async {
    _check();
    return rows.values.toList();
  }

  @override
  Future<void> upsert(List<MealEntry> entries) async {
    _check();
    if (entries.isNotEmpty) upsertCalls++;
    for (final e in entries) {
      rows[e.id] = e;
    }
  }

  @override
  Future<void> delete(List<String> ids) async {
    _check();
    ids.forEach(rows.remove);
  }
}

/// Stands in for storage and the `analyze-meal` function. [results] is
/// consumed one per analysis, so a test can fail once and then succeed.
class FakeMealPhotoService implements MealPhotoService {
  FakeMealPhotoService(this.results);

  final List<Object> results;
  final uploads = <String>[];
  final removed = <String>[];

  @override
  Future<String> upload({
    required String userId,
    required String mealId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '$userId/$mealId.$extension';
    uploads.add(path);
    return path;
  }

  @override
  Future<MealDraft> analyze(String photoPath) async {
    final next = results.removeAt(0);
    if (next is AnalysisFailure) throw next;
    return next as MealDraft;
  }

  @override
  Future<void> remove(String photoPath) async => removed.add(photoPath);

  /// Tests stay offline, so a photo never loads; the screen shows its
  /// placeholder instead.
  @override
  Future<String> viewUrl(String photoPath) async =>
      throw Exception('offline in tests');
}

class FakeWeightRemote implements WeightRemote {
  final rows = <String, WeightEntry>{};
  bool offline = false;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<List<WeightEntry>> fetchAll() async {
    _check();
    return rows.values.toList();
  }

  @override
  Future<void> upsert(List<WeightEntry> entries) async {
    _check();
    for (final e in entries) {
      rows[e.key] = e;
    }
  }

  @override
  Future<void> delete(List<String> days) async {
    _check();
    days.forEach(rows.remove);
  }
}

/// Records deletions; set [failure] to make the next one fail that way.
class FakeAccountRemote implements AccountRemote {
  AccountDeletionFailure? failure;
  int deletions = 0;

  @override
  Future<void> deleteAccount() async {
    if (failure case final reason?) throw AccountDeletionException(reason);
    deletions++;
  }
}

class FakeProfileRemote implements ProfileRemote {
  final rows = <String, OnboardingAnswers>{};
  bool offline = false;

  @override
  Future<OnboardingAnswers?> fetch(String userId) async {
    if (offline) throw Exception('offline');
    return rows[userId];
  }

  @override
  Future<void> upsert(String userId, OnboardingAnswers answers) async {
    if (offline) throw Exception('offline');
    rows[userId] = answers;
  }
}
