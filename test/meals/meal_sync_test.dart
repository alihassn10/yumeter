import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/meals/data/meal_log_store.dart';
import 'package:yumeter/features/meals/data/meal_remote.dart';
import 'package:yumeter/features/meals/domain/meal_entry.dart';
import 'package:yumeter/features/meals/state/meal_log_controller.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MealEntry meal(String id, {String name = 'Oats', int calories = 300}) =>
      MealEntry(
        id: id,
        loggedAt: DateTime(2026, 10, 10, 8),
        type: MealType.breakfast,
        name: name,
        calories: calories,
      );

  group('signed in', () {
    late FakeMealRemote remote;

    setUp(() => remote = FakeMealRemote());

    Future<MealLogController> signedInLog() async {
      final container = testContainer(
        await testPrefs(),
        auth: FakeAuthRepository(user: testUser),
        meals: remote,
      );
      addTearDown(container.dispose);
      return container.read(mealLogProvider.notifier);
    }

    test('a logged meal reaches the account and leaves the queue', () async {
      final log = await signedInLog();
      final entry = await log.add(
        type: MealType.lunch,
        name: 'Wrap',
        calories: 540,
        loggedAt: DateTime(2026, 10, 10, 12),
      );
      await log.sync();

      expect(remote.rows[entry.id]?.name, 'Wrap');
      expect(log.unsyncedCount, 0);
    });

    test('a deleted meal is deleted on the account too', () async {
      final log = await signedInLog();
      final entry = await log.add(
        type: MealType.lunch,
        name: 'Wrap',
        calories: 540,
        loggedAt: DateTime(2026, 10, 10, 12),
      );
      await log.sync();
      await log.remove(entry.id);
      await log.sync();

      expect(remote.rows, isEmpty);
      expect(log.unsyncedCount, 0);
    });

    test('meals logged offline wait in the queue, then go up', () async {
      remote.offline = true;
      final log = await signedInLog();
      final entry = await log.add(
        type: MealType.snack,
        name: 'Apple',
        calories: 95,
        loggedAt: DateTime(2026, 10, 10, 15),
      );
      await log.sync();
      expect(log.unsyncedCount, 1);
      expect(log.state.single.id, entry.id, reason: 'still on the phone');

      remote.offline = false;
      await log.sync();
      expect(remote.rows.keys, [entry.id]);
      expect(log.unsyncedCount, 0);
    });

    test('meals from another device are pulled in', () async {
      remote.rows['remote-1'] = meal('remote-1', name: 'From tablet');
      final log = await signedInLog();
      await log.sync();

      expect(log.state.map((e) => e.name), ['From tablet']);
    });

    test('a meal deleted on another device disappears here', () async {
      final log = await signedInLog();
      final entry = await log.add(
        type: MealType.lunch,
        name: 'Wrap',
        calories: 540,
        loggedAt: DateTime(2026, 10, 10, 12),
      );
      await log.sync();

      remote.rows.remove(entry.id);
      await log.sync();
      expect(log.state, isEmpty);
    });

    test('an unsynced delete is not undone by the pull', () async {
      remote.rows['m1'] = meal('m1');
      final log = await signedInLog();
      await log.sync();

      remote.offline = true;
      await log.remove('m1');
      await log.sync();
      expect(log.state, isEmpty);

      // Back online the delete goes up before the pull, so m1 stays gone.
      remote.offline = false;
      await log.sync();
      expect(log.state, isEmpty);
      expect(remote.rows, isEmpty);
    });
  });

  test('signed out, nothing is sent and the queue is kept', () async {
    final remote = FakeMealRemote();
    final container = testContainer(await testPrefs(), meals: remote);
    addTearDown(container.dispose);
    final log = container.read(mealLogProvider.notifier);

    await log.add(
      type: MealType.lunch,
      name: 'Wrap',
      calories: 540,
      loggedAt: DateTime(2026, 10, 10, 12),
    );
    await log.sync();

    expect(remote.rows, isEmpty);
    expect(log.unsyncedCount, 1);
  });

  group('MealLogStore queue', () {
    test('keeps only the newest change per meal', () async {
      final store = MealLogStore(await testPrefs());
      await store.markPending({'m1': PendingOp.upsert});
      await store.markPending({'m1': PendingOp.delete});

      final pending = store.loadPending();
      expect(pending.keys, ['m1']);
      expect(pending['m1']!.op, PendingOp.delete);
    });

    test('survives a damaged queue', () async {
      final store = MealLogStore(
        await testPrefs(extra: {'meals.pending.v1': 'not json'}),
      );
      expect(store.loadPending(), isEmpty);
    });
  });

  group('meal rows', () {
    final entry = MealEntry(
      id: 'abc',
      loggedAt: DateTime(2026, 10, 10, 23, 30),
      type: MealType.dinner,
      name: 'Late pasta',
      calories: 700,
      proteinGrams: 25,
      carbGrams: 90,
      fatGrams: 22,
      source: MealSource.quickAdd,
    );

    test('send the time in UTC and read it back as the same moment', () {
      final row = mealToRow(entry);
      expect(row['logged_at'], endsWith('Z'));

      final back = mealFromRow(row)!;
      expect(back.loggedAt, entry.loggedAt);
      expect(back.loggedAt.isUtc, isFalse, reason: 'shown in local time');
    });

    test('round-trip every field', () {
      final back = mealFromRow(mealToRow(entry))!;
      expect(back.id, entry.id);
      expect(back.type, entry.type);
      expect(back.name, entry.name);
      expect(back.calories, entry.calories);
      expect(back.proteinGrams, entry.proteinGrams);
      expect(back.carbGrams, entry.carbGrams);
      expect(back.fatGrams, entry.fatGrams);
      expect(back.source, entry.source);
    });

    test('never claim an owner; the database sets it', () {
      expect(mealToRow(entry).containsKey('user_id'), isFalse);
    });

    test('fit the name to what the database accepts', () {
      expect(mealToRow(entry.copyWith(name: '   '))['name'], 'Meal');
      expect(
        (mealToRow(entry.copyWith(name: 'x' * 300))['name'] as String).length,
        200,
      );
    });

    test('skip a row with no usable time', () {
      expect(mealFromRow({...mealToRow(entry), 'logged_at': null}), isNull);
    });
  });
}
