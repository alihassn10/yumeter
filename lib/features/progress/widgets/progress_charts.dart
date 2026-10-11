import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../domain/progress_stats.dart';

/// Calories per bar against the daily target.
///
/// One series, so no legend: the card title names it. The target is a dashed
/// reference line on the same axis rather than a second scale. Days with
/// nothing logged draw no bar, because an unlogged day is unknown, not zero.
class CalorieChart extends StatelessWidget {
  const CalorieChart({super.key, required this.bars, this.target});

  final List<CalorieBar> bars;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final peak = bars.fold<int>(0, (m, b) => math.max(m, b.calories));
    final top = _niceCeiling(math.max(peak, target ?? 0) * 1.15, minimum: 500);
    final interval = top / 4;
    // Label at most about seven bars so the axis never collides.
    final labelEvery = math.max(1, (bars.length / 7).ceil());

    return Semantics(
      label: _describe(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth =
              (constraints.maxWidth / math.max(bars.length, 1) * 0.55)
                  .clamp(3.0, 20.0);
          return BarChart(
            BarChartData(
              minY: 0,
              maxY: top,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.track, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(_compact(value), style: _axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i % labelEvery != 0 || i >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(bars[i].label, style: _axisStyle),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (target case final t?)
                    // Unlabelled: recent bars sit on the right, where a label
                    // would cover them. The card caption names the line.
                    HorizontalLine(
                      y: t.toDouble(),
                      color: AppColors.textSecondary,
                      strokeWidth: 1.5,
                      dashArray: const [6, 4],
                    ),
                ],
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.track,
                  getTooltipItem: (group, _, _, _) {
                    final bar = bars[group.x];
                    final when = _when(bar);
                    return BarTooltipItem(
                      bar.hasData
                          ? '$when\n${groupedNumber(bar.calories)} kcal'
                              '${bar.loggedDays > 1 ? ' a day' : ''}'
                          : '$when\nNothing logged',
                      AppTypography.labelMedium
                          .copyWith(color: AppColors.textPrimary),
                    );
                  },
                ),
              ),
              barGroups: [
                for (final (i, bar) in bars.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bar.calories.toDouble(),
                        width: barWidth,
                        color: AppColors.calories,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _when(CalorieBar bar) => switch (bar.span) {
        BarSpan.day => Dates.friendlyDay(bar.start),
        BarSpan.week => 'Week of ${_shortDate(bar.start)}',
        BarSpan.month => '${bar.label} ${bar.start.year}',
      };

  String _describe() {
    final logged = bars.where((b) => b.hasData).toList();
    if (logged.isEmpty) return 'Calorie chart: nothing logged in this period.';
    final avg = logged.fold<int>(0, (s, b) => s + b.calories) ~/ logged.length;
    return 'Calorie chart: ${logged.length} of ${bars.length} bars logged, '
        'averaging ${groupedNumber(avg)} kcal'
        '${target != null ? ' against a target of ${groupedNumber(target!)}' : ''}.';
  }
}

/// Weight over time with the goal as a dashed reference line.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.points,
    required this.unit,
    this.goal,
  });

  /// (day, weight in display units), oldest first. Needs at least two.
  final List<(DateTime, double)> points;
  final String unit;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final first = points.first.$1;
    final values = [for (final p in points) p.$2, ?goal];
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.15, 1.0);
    final spanDays = points.last.$1.difference(first).inDays.toDouble();

    String fmt(double v) => v.toStringAsFixed(1);

    return Semantics(
      label: 'Weight chart: ${fmt(points.first.$2)} to '
          '${fmt(points.last.$2)} $unit over ${spanDays.toInt()} days'
          '${goal != null ? ', goal ${fmt(goal!)} $unit' : ''}.',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(spanDays, 1),
          minY: (lo - pad).floorToDouble(),
          maxY: (hi + pad).ceilToDouble(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.track, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(value.toStringAsFixed(0), style: _axisStyle),
                ),
              ),
            ),
            // First and last dates only: enough to read the span, never
            // crowded.
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(spanDays, 1),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  // Keeps the first and last dates from hanging off the edges.
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    _shortDate(Dates.addDays(first, value.round())),
                    style: _axisStyle,
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (goal case final g?)
                HorizontalLine(
                  y: g,
                  color: AppColors.textSecondary,
                  strokeWidth: 1.5,
                  dashArray: const [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: _axisStyle,
                    labelResolver: (_) => 'Goal ${fmt(g)}',
                  ),
                ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.track,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${_shortDate(Dates.addDays(first, s.x.round()))}\n'
                    '${fmt(s.y)} $unit',
                    AppTypography.labelMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (day, v) in points)
                  FlSpot(day.difference(first).inDays.toDouble(), v),
              ],
              color: AppColors.textPrimary,
              barWidth: 2,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                  strokeColor: AppColors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Share of calories from each macro, as one bar of three labelled segments.
class MacroSplitBar extends StatelessWidget {
  const MacroSplitBar({super.key, required this.split});

  final MacroSplit split;

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Protein', split.proteinShare, split.proteinGrams, AppColors.protein),
      ('Carbs', split.carbShare, split.carbGrams, AppColors.carbs),
      ('Fat', split.fatShare, split.fatGrams, AppColors.fat),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final (i, (_, share, _, color)) in parts.indexed)
                  if (share > 0) ...[
                    // A 2px surface gap between fills.
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: math.max(1, (share * 1000).round()),
                      child: ColoredBox(color: color),
                    ),
                  ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final (name, share, grams, color) in parts)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4, right: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.bodySmall),
                          Text(
                            '${(share * 100).round()}%',
                            style: AppTypography.metricSub,
                          ),
                          Text(
                            '${grams}g a day',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

TextStyle get _axisStyle =>
    AppTypography.labelSmall.copyWith(color: AppColors.textHint);

String _compact(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : '${v.round()}';

String _shortDate(DateTime d) => '${Dates.monthsShort[d.month - 1]} ${d.day}';

/// Rounds up to 1, 2 or 5 × a power of ten, so axis ticks land on round
/// numbers.
double _niceCeiling(double v, {required double minimum}) {
  if (v <= minimum) return minimum;
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final step in [1, 2, 2.5, 5, 10]) {
    if (step * magnitude >= v) return step * magnitude;
  }
  return 10 * magnitude;
}
