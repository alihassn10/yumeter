import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What still has to reach the server for one record.
enum PendingOp { upsert, delete }

/// A change made on this phone that the server has not confirmed yet.
///
/// [stamp] tells two changes to the same record apart, so a push only clears
/// the change it actually sent and not a newer edit made while it was in
/// flight.
class PendingChange {
  const PendingChange(this.op, this.stamp);

  final PendingOp op;
  final int stamp;
}

/// Unsynced changes for one kind of record, keyed by the record's id and kept
/// in shared preferences so they survive the app being closed.
class PendingQueue {
  const PendingQueue(this._prefs, this._key);

  final SharedPreferences _prefs;
  final String _key;

  /// Latest unsynced change per id. Only the newest intent matters: a record
  /// added then deleted offline needs a delete, nothing else.
  Map<String, PendingChange> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final pending = <String, PendingChange>{};
      decoded.forEach((id, value) {
        if (value is! Map<String, dynamic>) return;
        final op = PendingOp.values.asNameMap()[value['op']];
        final stamp = value['stamp'];
        if (op != null && stamp is int) pending[id] = PendingChange(op, stamp);
      });
      return pending;
    } on FormatException {
      return {};
    }
  }

  Future<void> save(Map<String, PendingChange> pending) => _prefs.setString(
        _key,
        jsonEncode({
          for (final MapEntry(:key, :value) in pending.entries)
            key: {'op': value.op.name, 'stamp': value.stamp},
        }),
      );

  /// Queues [ops] on top of whatever is already waiting.
  Future<void> mark(Map<String, PendingOp> ops) {
    if (ops.isEmpty) return Future.value();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return save({
      ...load(),
      for (final MapEntry(:key, :value) in ops.entries)
        key: PendingChange(value, stamp),
    });
  }

  /// Removes the changes in [sent] that have not been replaced since.
  Future<void> acknowledge(Map<String, PendingChange> sent) {
    final now = load()
      ..removeWhere((id, change) => sent[id]?.stamp == change.stamp);
    return save(now);
  }

  Future<void> clear() => _prefs.remove(_key);
}
