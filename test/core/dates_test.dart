import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/utils/dates.dart';
import 'package:yumeter/core/utils/format.dart';

void main() {
  group('friendlyDay', () {
    final now = DateTime(2026, 10, 10, 15, 30);

    test('names today and yesterday', () {
      expect(Dates.friendlyDay(DateTime(2026, 10, 10, 8), now: now), 'Today');
      expect(
        Dates.friendlyDay(DateTime(2026, 10, 9, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('spells out anything older', () {
      expect(Dates.friendlyDay(DateTime(2026, 10, 5), now: now), 'Mon, Oct 5');
    });
  });

  test('startOfWeek lands on the Monday of the same week', () {
    // 10 Oct 2026 is a Saturday.
    expect(Dates.startOfWeek(DateTime(2026, 10, 10, 18)), DateTime(2026, 10, 5));
    // A Monday is its own start.
    expect(Dates.startOfWeek(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    // A Sunday belongs to the week before it.
    expect(Dates.startOfWeek(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
  });

  test('addDays steps by calendar date across month and year ends', () {
    expect(Dates.addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
    expect(Dates.addDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
  });

  test('time uses a 12-hour clock', () {
    expect(Dates.time(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(Dates.time(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(Dates.time(DateTime(2026, 1, 1, 13, 30)), '1:30 PM');
  });

  test('groupedNumber inserts thousands separators', () {
    expect(groupedNumber(0), '0');
    expect(groupedNumber(999), '999');
    expect(groupedNumber(1000), '1,000');
    expect(groupedNumber(1240), '1,240');
    expect(groupedNumber(1234567), '1,234,567');
    expect(groupedNumber(-1500), '-1,500');
  });
}
