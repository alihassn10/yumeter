/// Calendar helpers. Everything here works in the device's local time, which
/// is what "today" means to the person holding the phone.
abstract final class Dates {
  static const monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Midnight at the start of [d]'s calendar day.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Steps by calendar day rather than by 24 hours, so a daylight-saving
  /// change cannot skip or repeat a date.
  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Monday of the week containing [d].
  static DateTime startOfWeek(DateTime d) =>
      addDays(dateOnly(d), -(d.weekday - DateTime.monday));

  /// "Today", "Yesterday", or "Mon, Oct 6".
  static String friendlyDay(DateTime d, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final day = dateOnly(d);
    if (day == today) return 'Today';
    if (day == addDays(today, -1)) return 'Yesterday';
    return '${weekdaysShort[day.weekday - 1]}, '
        '${monthsShort[day.month - 1]} ${day.day}';
  }

  /// "8:05 AM".
  static String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}
