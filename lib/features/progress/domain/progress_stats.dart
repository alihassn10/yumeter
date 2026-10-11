import '../../../core/utils/dates.dart';
import '../../meals/domain/meal_entry.dart';
import 'weight_entry.dart';

/// The time window the Progress tab summarises.
enum ProgressRange {
  week('Week', 7),
  month('Month', 30),
  quarter('3 Months', 90),
  all('All time', null);

  const ProgressRange(this.label, this.days);

  final String label;

  /// Window length ending today, or null for everything on record.
  final int? days;
}

/// How much time one calorie bar covers.
enum BarSpan { day, week, month }

/// One bar on the calorie chart: a day, or for longer ranges a week or month
/// averaged over the days that were logged.
class CalorieBar {
  const CalorieBar({
    required this.start,
    required this.span,
    required this.label,
    required this.calories,
    required this.loggedDays,
  });

  final DateTime start;
  final BarSpan span;
  final String label;

  /// The day's total, or the average per logged day in a longer bucket.
  final int calories;

  /// Zero means nothing was logged: an empty bar, not a 0 kcal day.
  final int loggedDays;

  bool get hasData => loggedDays > 0;
}

/// Share of energy from each macro, and the average grams per logged day.
class MacroSplit {
  const MacroSplit({
    required this.proteinShare,
    required this.carbShare,
    required this.fatShare,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
  });

  final double proteinShare;
  final double carbShare;
  final double fatShare;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
}

class ProgressSummary {
  const ProgressSummary({
    required this.start,
    required this.daysInRange,
    required this.loggedDays,
    required this.averageCalories,
    required this.averageProteinGrams,
    required this.macros,
    required this.bars,
  });

  final DateTime start;
  final int daysInRange;
  final int loggedDays;

  /// Per logged day; null when nothing was logged. Days with no entries are
  /// left out, since an unlogged day is unknown, not a day of fasting.
  final int? averageCalories;
  final int? averageProteinGrams;

  /// Null when no meal in range had macros entered.
  final MacroSplit? macros;

  final List<CalorieBar> bars;
}

/// First day of [range] ending on [today]. "All time" starts at the earliest
/// meal or weigh-in, or today when there is neither.
DateTime rangeStart(
  ProgressRange range, {
  required DateTime today,
  Iterable<MealEntry> meals = const [],
  Iterable<WeightEntry> weights = const [],
}) {
  final day = Dates.dateOnly(today);
  if (range.days case final days?) return Dates.addDays(day, -(days - 1));
  var earliest = day;
  for (final m in meals) {
    final d = Dates.dateOnly(m.loggedAt);
    if (d.isBefore(earliest)) earliest = d;
  }
  for (final w in weights) {
    if (w.day.isBefore(earliest)) earliest = w.day;
  }
  return earliest;
}

ProgressSummary summarize(
  List<MealEntry> meals,
  ProgressRange range, {
  required DateTime today,
}) {
  final end = Dates.dateOnly(today);
  final start = rangeStart(range, today: today, meals: meals);
  final inRange = [
    for (final m in meals)
      if (!Dates.dateOnly(m.loggedAt).isBefore(start) &&
          !Dates.dateOnly(m.loggedAt).isAfter(end))
        m,
  ];

  // Totals per calendar day.
  final byDay = <DateTime, DayTotals>{};
  final grouped = <DateTime, List<MealEntry>>{};
  for (final m in inRange) {
    grouped.putIfAbsent(Dates.dateOnly(m.loggedAt), () => []).add(m);
  }
  grouped.forEach((day, entries) => byDay[day] = DayTotals.of(entries));

  final logged = byDay.length;
  final totals = DayTotals.of(inRange);

  return ProgressSummary(
    start: start,
    daysInRange: end.difference(start).inDays + 1,
    loggedDays: logged,
    averageCalories: logged == 0 ? null : (totals.calories / logged).round(),
    averageProteinGrams:
        logged == 0 ? null : (totals.proteinGrams / logged).round(),
    macros: _macros(totals, logged),
    bars: _bars(byDay, range, start: start, end: end),
  );
}

MacroSplit? _macros(DayTotals t, int loggedDays) {
  final p = t.proteinGrams * 4.0, c = t.carbGrams * 4.0, f = t.fatGrams * 9.0;
  final energy = p + c + f;
  if (energy <= 0 || loggedDays == 0) return null;
  return MacroSplit(
    proteinShare: p / energy,
    carbShare: c / energy,
    fatShare: f / energy,
    proteinGrams: (t.proteinGrams / loggedDays).round(),
    carbGrams: (t.carbGrams / loggedDays).round(),
    fatGrams: (t.fatGrams / loggedDays).round(),
  );
}

/// Daily bars up to a month; weekly beyond that; monthly once weekly bars
/// would be too thin to read (over 26 weeks).
List<CalorieBar> _bars(
  Map<DateTime, DayTotals> byDay,
  ProgressRange range, {
  required DateTime start,
  required DateTime end,
}) {
  final days = end.difference(start).inDays + 1;

  if (range == ProgressRange.week || range == ProgressRange.month) {
    return [
      for (var i = 0; i < days; i++)
        _bucket(byDay, Dates.addDays(start, i), 1, range: range),
    ];
  }

  if (days <= 26 * 7) {
    final bars = <CalorieBar>[];
    for (var w = Dates.startOfWeek(start);
        !w.isAfter(end);
        w = Dates.addDays(w, 7)) {
      bars.add(_bucket(byDay, w, 7, range: range));
    }
    return bars;
  }

  final bars = <CalorieBar>[];
  for (var m = DateTime(start.year, start.month);
      !m.isAfter(end);
      m = DateTime(m.year, m.month + 1)) {
    final length = DateTime(m.year, m.month + 1).difference(m).inDays;
    bars.add(_bucket(byDay, m, length, range: range, monthly: true));
  }
  return bars;
}

CalorieBar _bucket(
  Map<DateTime, DayTotals> byDay,
  DateTime start,
  int length, {
  required ProgressRange range,
  bool monthly = false,
}) {
  var total = 0, logged = 0;
  for (var i = 0; i < length; i++) {
    if (byDay[Dates.addDays(start, i)] case final t?) {
      total += t.calories;
      logged++;
    }
  }
  final label = monthly
      ? Dates.monthsShort[start.month - 1]
      : length == 7
          ? '${start.day}/${start.month}'
          : range == ProgressRange.week
              ? Dates.weekdaysShort[start.weekday - 1].substring(0, 1)
              : '${start.day}';
  return CalorieBar(
    start: start,
    span: monthly
        ? BarSpan.month
        : length == 7
            ? BarSpan.week
            : BarSpan.day,
    label: label,
    calories: logged == 0 ? 0 : (total / logged).round(),
    loggedDays: logged,
  );
}

/// Weigh-ins from [start] on, oldest first.
List<WeightEntry> weightsSince(List<WeightEntry> weights, DateTime start) =>
    [for (final w in weights) if (!w.day.isBefore(start)) w];
