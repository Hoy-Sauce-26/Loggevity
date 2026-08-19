import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_format.dart';

/// One week's composite score.
class TrendPoint {
  const TrendPoint(this.weekStart, this.compositePercent);

  final DateTime weekStart;
  final double compositePercent;
}

/// Line chart of the weekly composite score.
///
/// The y-axis is not pinned to 0-100: composite scores can go negative, and a
/// run of good weeks all sitting near the top of a fixed axis would flatten
/// out the differences worth seeing. The axis follows the data instead, with
/// a zero line for reference whenever the range crosses it.
class ScoreTrendChart extends StatelessWidget {
  const ScoreTrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((p) => p.compositePercent).toList();
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);

    // Pad the range so the line never rides the frame, and always include 0.
    final minY = (lowest < 0 ? lowest : 0.0) - 5;
    final maxY = (highest > 0 ? highest : 0.0) + 5;
    final interval = niceInterval(maxY - minY, emptyFallback: 10);
    final labelEvery = (points.length / 4).ceil().clamp(1, points.length);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          extraLinesData: minY < 0
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: theme.colorScheme.outline,
                    strokeWidth: 1,
                    dashArray: const [6, 4],
                  ),
                ])
              : const ExtraLinesData(),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.round()}%',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // Thin the labels out rather than letting them overlap.
                  if (i % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      shortDate(points[i].weekStart),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].compositePercent),
              ],
              isCurved: false,
              barWidth: 3,
              color: theme.colorScheme.primary,
              // Individual weeks are the unit of meaning here, so mark each
              // one rather than implying a continuous signal.
              dotData: FlDotData(show: points.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                applyCutOffY: true,
                cutOffY: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
