import '../../../core/utils/dates.dart';

/// One weigh-in. A day holds at most one; logging again replaces it.
class WeightEntry {
  WeightEntry({required DateTime day, required this.weightKg})
      : day = Dates.dateOnly(day);

  /// Midnight at the start of the calendar day it was logged for.
  final DateTime day;

  /// Always metric; the units preference only changes how it is shown.
  final double weightKg;

  /// The record's key: the day as `yyyy-mm-dd`, same as the server's
  /// `logged_on`, so no time zone can move an entry to another day.
  String get key => dayKey(day);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parses `yyyy-mm-dd` as a local calendar day, or null if malformed.
  static DateTime? parseDay(Object? value) {
    if (value is! String) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final [y, m, d] = [for (final p in parts) int.tryParse(p)];
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Map<String, dynamic> toJson() => {'day': key, 'weightKg': weightKg};

  /// Null for a damaged record, so one bad entry cannot hide the rest.
  static WeightEntry? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final day = parseDay(json['day']);
    final kg = json['weightKg'];
    if (day == null || kg is! num || kg <= 0) return null;
    return WeightEntry(day: day, weightKg: kg.toDouble());
  }
}
