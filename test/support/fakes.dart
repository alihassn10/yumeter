import 'dart:async';

import 'package:yumeter/core/storage/profile_remote.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/meals/data/meal_remote.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

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
