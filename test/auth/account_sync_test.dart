import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/storage/profile_remote.dart';
import 'package:yumeter/core/storage/profile_store.dart';
import 'package:yumeter/features/auth/data/account_sync.dart';
import 'package:yumeter/features/auth/data/auth_repository.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late FakeMealRemote meals;
  late FakeProfileRemote profiles;

  setUp(() {
    auth = FakeAuthRepository();
    meals = FakeMealRemote();
    profiles = FakeProfileRemote();
  });

  Future<ProviderContainer> container({
    OnboardingAnswers? profile,
    Map<String, Object> extra = const {},
  }) async {
    final c = testContainer(
      await testPrefs(profile: profile, extra: extra),
      auth: auth,
      meals: meals,
      profiles: profiles,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Signs in through the fake, the way the sign-in screen does.
  Future<bool> signIn(ProviderContainer c, {AuthUser as = testUser}) async {
    auth.signInAs = as;
    final user = await auth.verifyCode(email: as.email!, code: '123456');
    final hasProfile = await c.read(accountSyncProvider).signedIn(user);
    await c.read(mealLogProvider.notifier).sync();
    return hasProfile;
  }

  Future<void> logMeal(ProviderContainer c, String name) =>
      c.read(mealLogProvider.notifier).add(
            type: MealType.lunch,
            name: name,
            calories: 400,
            loggedAt: DateTime(2026, 10, 10, 12),
          );

  test('first sign-in keeps what was logged before and uploads it', () async {
    final c = await container(profile: sampleProfile);
    await logMeal(c, 'Before account');

    final hasProfile = await signIn(c);

    expect(hasProfile, isTrue);
    expect(meals.rows.values.map((e) => e.name), ['Before account']);
    expect(profiles.rows[testUser.id]?.weightKg, sampleProfile.weightKg);
    expect(c.read(accountSyncProvider).unsyncedCount, 0);
  });

  test('an account profile wins over a pre-account draft', () async {
    profiles.rows[testUser.id] = sampleProfile.copyWith(weightKg: 80);
    final c = await container(profile: sampleProfile);

    await signIn(c);

    expect(c.read(profileStoreProvider).load()?.weightKg, 80);
    expect(profiles.rows[testUser.id]?.weightKg, 80);
  });

  test('a returning user on a fresh install gets their profile back',
      () async {
    profiles.rows[testUser.id] = sampleProfile;
    final c = await container();

    expect(await signIn(c), isTrue);
    expect(c.read(storedProfileProvider)?.heightCm, sampleProfile.heightCm);
  });

  test('a new account with nothing on the phone goes to onboarding', () async {
    final c = await container();
    expect(await signIn(c), isFalse);
  });

  test("another person's data is wiped when a new account signs in",
      () async {
    final c = await container(
      profile: sampleProfile,
      extra: {'account.owner': otherUser.id},
    );
    await logMeal(c, "Someone else's lunch");

    final hasProfile = await signIn(c);

    expect(hasProfile, isFalse);
    expect(c.read(mealLogProvider), isEmpty);
    expect(meals.rows, isEmpty, reason: 'nothing of theirs was uploaded');
  });

  test('sign-out wipes the phone and forgets the owner', () async {
    final c = await container(profile: sampleProfile);
    await signIn(c);
    await logMeal(c, 'Lunch');

    await c.read(accountSyncProvider).signOut();

    expect(c.read(currentUserProvider), isNull);
    expect(c.read(mealLogProvider), isEmpty);
    expect(c.read(storedProfileProvider), isNull);
    // The account still has everything.
    expect(meals.rows.values.map((e) => e.name), ['Lunch']);
  });

  test('signing out offline still wipes the phone', () async {
    final c = await container(profile: sampleProfile);
    await signIn(c);
    await logMeal(c, 'Lunch');
    auth.offline = true;

    await c.read(accountSyncProvider).signOut();

    expect(c.read(currentUserProvider), isNull);
    expect(c.read(mealLogProvider), isEmpty);
    expect(c.read(storedProfileProvider), isNull);
  });

  test('changes made offline are counted before sign-out', () async {
    final c = await container();
    await signIn(c);
    meals.offline = true;
    profiles.offline = true;

    await logMeal(c, 'Offline lunch');
    await c.read(accountSyncProvider).saveProfile(sampleProfile);
    await c.read(accountSyncProvider).syncAll();

    expect(c.read(accountSyncProvider).unsyncedCount, 2);
  });

  test('a profile saved offline goes up on the next sync', () async {
    final c = await container();
    await signIn(c);
    profiles.offline = true;
    await c.read(accountSyncProvider).saveProfile(sampleProfile);
    expect(c.read(profileStoreProvider).pending, isTrue);

    profiles.offline = false;
    await c.read(accountSyncProvider).syncAll();

    expect(profiles.rows[testUser.id]?.goal, sampleProfile.goal);
    expect(c.read(profileStoreProvider).pending, isFalse);
  });

  group('profile rows', () {
    test('store the birth date as a plain calendar date', () {
      final row = profileToRow(testUser.id, sampleProfile);
      expect(row['birth_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(row['id'], testUser.id);
    });

    test('round-trip every answer', () {
      final back = profileFromRow(profileToRow(testUser.id, sampleProfile));
      expect(back.sex, sampleProfile.sex);
      expect(back.birthDate, sampleProfile.birthDate);
      expect(back.heightCm, sampleProfile.heightCm);
      expect(back.weightKg, sampleProfile.weightKg);
      expect(back.activityLevel, sampleProfile.activityLevel);
      expect(back.goal, sampleProfile.goal);
      expect(back.targetWeightKg, sampleProfile.targetWeightKg);
      expect(back.paceKgPerWeek, sampleProfile.paceKgPerWeek);
      expect(back.dietType, sampleProfile.dietType);
      expect(back.units, sampleProfile.units);
    });
  });
}
