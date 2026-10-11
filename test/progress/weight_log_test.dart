import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/storage/profile_store.dart';
import 'package:yumeter/features/auth/data/account_sync.dart';
import 'package:yumeter/features/progress/data/weight_log_store.dart';
import 'package:yumeter/features/progress/domain/weight_entry.dart';
import 'package:yumeter/features/progress/state/weight_log_controller.dart';

import '../support/fakes.dart';
import '../support/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWeightRemote remote;

  setUp(() => remote = FakeWeightRemote());

  Future<WeightLogController> signedInLog() async {
    final container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
      weights: remote,
    );
    addTearDown(container.dispose);
    return container.read(weightLogProvider.notifier);
  }

  test('a weigh-in reaches the account', () async {
    final log = await signedInLog();
    await log.log(DateTime(2026, 10, 11), 64.2);
    await log.sync();

    expect(remote.rows['2026-10-11']?.weightKg, 64.2);
    expect(log.unsyncedCount, 0);
  });

  test('a second weigh-in the same day replaces the first', () async {
    final log = await signedInLog();
    await log.log(DateTime(2026, 10, 11, 7), 64.6);
    await log.log(DateTime(2026, 10, 11, 21), 64.1);
    await log.sync();

    expect(log.state, hasLength(1));
    expect(log.state.single.weightKg, 64.1);
    expect(remote.rows, hasLength(1));
  });

  test('the latest weigh-in becomes the profile weight', () async {
    final container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
      weights: remote,
    );
    addTearDown(container.dispose);

    await container
        .read(weightLogProvider.notifier)
        .log(DateTime(2026, 10, 11), 63.0);
    expect(container.read(storedProfileProvider)?.weightKg, 63.0);

    // An older backfilled entry must not move the profile backwards.
    await container
        .read(weightLogProvider.notifier)
        .log(DateTime(2026, 10, 1), 66.0);
    expect(container.read(storedProfileProvider)?.weightKg, 63.0);
  });

  test('offline weigh-ins wait in the queue, then go up', () async {
    remote.offline = true;
    final log = await signedInLog();
    await log.log(DateTime(2026, 10, 11), 64.0);
    await log.sync();
    expect(log.unsyncedCount, 1);

    remote.offline = false;
    await log.sync();
    expect(remote.rows.keys, ['2026-10-11']);
    expect(log.unsyncedCount, 0);
  });

  test('weigh-ins from another device are pulled in', () async {
    remote.rows['2026-10-05'] =
        WeightEntry(day: DateTime(2026, 10, 5), weightKg: 65.5);
    final log = await signedInLog();
    await log.sync();

    expect(log.state.single.key, '2026-10-05');
  });

  test('deleting a weigh-in deletes it on the account', () async {
    final log = await signedInLog();
    await log.log(DateTime(2026, 10, 11), 64.0);
    await log.sync();
    await log.remove(log.state.single);
    await log.sync();

    expect(remote.rows, isEmpty);
  });

  test('sign-out wipes weigh-ins from the phone', () async {
    final container = testContainer(
      await testPrefs(profile: sampleProfile),
      auth: FakeAuthRepository(user: testUser),
      weights: remote,
    );
    addTearDown(container.dispose);
    await container
        .read(weightLogProvider.notifier)
        .log(DateTime(2026, 10, 11), 64.0);

    await container.read(accountSyncProvider).signOut();

    expect(container.read(weightLogProvider), isEmpty);
    expect(container.read(weightLogStoreProvider).queue.load(), isEmpty);
  });

  test('rows fit the table check and key on the day', () {
    final row = weightToRow(WeightEntry(day: DateTime(2026, 1, 2), weightKg: 999));
    expect(row['weight_kg'], 400);
    expect(row['logged_on'], '2026-01-02');
    expect(weightFromRow({'logged_on': '2026-01-02', 'weight_kg': 70.5})?.weightKg,
        70.5);
  });
}
