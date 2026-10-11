import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/pending_queue.dart';
import '../../../core/storage/profile_store.dart';
import '../../auth/data/account_sync.dart';
import '../../auth/data/auth_repository.dart';
import '../data/weight_log_store.dart';
import '../domain/weight_entry.dart';

/// Every weigh-in, oldest first. Local first, synced in the background, the
/// same way as the meal log.
class WeightLogController extends Notifier<List<WeightEntry>> {
  Future<void> _queue = Future.value();

  WeightLogStore get _store => ref.read(weightLogStoreProvider);

  @override
  List<WeightEntry> build() {
    final entries = _sorted(ref.watch(weightLogStoreProvider).load());
    if (ref.read(currentUserProvider) != null) Future.microtask(sync);
    return entries;
  }

  List<WeightEntry> _sorted(Iterable<WeightEntry> entries) =>
      [...entries]..sort((a, b) => a.day.compareTo(b.day));

  /// Records [weightKg] for [day], replacing that day's earlier entry.
  ///
  /// A weigh-in for the latest day also becomes the profile's current weight,
  /// so the daily targets follow the user's actual weight rather than the
  /// one entered at onboarding.
  Future<void> log(DateTime day, double weightKg) async {
    final entry = WeightEntry(day: day, weightKg: weightKg);
    final isLatest = state.every((e) => !e.day.isAfter(entry.day));
    await _commit(
      [for (final e in state) if (e.key != entry.key) e, entry],
      {entry.key: PendingOp.upsert},
    );

    if (!ref.mounted) return;
    final profile = ref.read(storedProfileProvider);
    if (isLatest && profile != null) {
      await ref
          .read(accountSyncProvider)
          .saveProfile(profile.copyWith(weightKg: entry.weightKg));
    }
  }

  Future<void> remove(WeightEntry entry) => _commit(
        [for (final e in state) if (e.key != entry.key) e],
        {entry.key: PendingOp.delete},
      );

  Future<void> _commit(
    List<WeightEntry> next,
    Map<String, PendingOp> changes,
  ) async {
    final store = _store;
    state = _sorted(next);
    await store.save(state);
    await store.queue.mark(changes);
    unawaited(_enqueue(_push));
  }

  /// Sends queued changes, then brings in weigh-ins from other devices.
  Future<void> sync() => _enqueue(() async {
        await _push();
        await _pull();
      });

  int get unsyncedCount => _store.queue.load().length;

  Future<void> _enqueue(Future<void> Function() task) {
    return _queue = _queue.then((_) async {
      if (!ref.mounted || ref.read(currentUserProvider) == null) return;
      try {
        await task();
      } on Exception catch (e) {
        debugPrint('Weight sync deferred: $e');
      }
    });
  }

  Future<void> _push() async {
    final store = _store;
    final sent = store.queue.load();
    if (sent.isEmpty) return;

    final remote = ref.read(weightRemoteProvider);
    final byKey = {for (final e in state) e.key: e};
    await remote.upsert([
      for (final MapEntry(:key, :value) in sent.entries)
        if (value.op == PendingOp.upsert) ?byKey[key],
    ]);
    await remote.delete([
      for (final MapEntry(:key, :value) in sent.entries)
        if (value.op == PendingOp.delete) key,
    ]);
    if (!ref.mounted) return;
    await store.queue.acknowledge(sent);
  }

  Future<void> _pull() async {
    if (!ref.mounted) return;
    final userId = ref.read(currentUserProvider)?.id;
    final remote = await ref.read(weightRemoteProvider).fetchAll();
    if (!ref.mounted || ref.read(currentUserProvider)?.id != userId) return;

    // The account wins, except for changes still waiting to go up.
    final local = {for (final e in state) e.key: e};
    final merged = {for (final e in remote) e.key: e};
    _store.queue.load().forEach((key, change) {
      if (change.op == PendingOp.delete) {
        merged.remove(key);
      } else if (local[key] case final entry?) {
        merged[key] = entry;
      }
    });

    state = _sorted(merged.values);
    await _store.save(state);
  }
}

final weightLogProvider =
    NotifierProvider<WeightLogController, List<WeightEntry>>(
  WeightLogController.new,
);
