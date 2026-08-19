import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../scoring/scoring.dart';
import '../category_presentation.dart';
import 'chart_format.dart';

/// One week's weighted points, per category.
class ContributionWeek {
  const ContributionWeek(this.weekStart, this.pointsByCategory);

  final DateTime weekStart;
  final Map<ActivityCategory, double> pointsByCategory;
}

/// Stacked bars showing which categories produced each week's score.
///
/// Weighted points rather than raw sub-scores, so a bar's height is the actual
/// contribution to the composite - socializing at 50x weight dwarfs
/// flexibility at 7x, and flattening that would misrepresent where the score
/// comes from.
///
/// Negative contributions (overtraining, sleep deprivation) stack downward
/// from zero instead of being dropped, because they are the part of a bad week
/// most worth seeing.
class CategoryContributionChart extends StatelessWidget {
  const CategoryContributionChart({super.key, required this.weeks});

  final List<ContributionWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var maxY = 0.0;
    var minY = 0.0;
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < weeks.length; i++) {
      final points = weeks[i].pointsByCategory;
      final stack = <BarChartRodStackItem>[];
      var up = 0.0;
      var down = 0.0;

      for (final category in ActivityCategory.values) {
        final value = points[category] ?? 0;
        if (value == 0) continue;
        final colour = categoryPresentation[category]!.colour;
        if (value > 0) {
          stack.add(BarChartRodStackItem(up, up + value, colour));
          up += value;
        } else {
          stack.add(BarChartRodStackItem(down + value, down, colour));
          down += value;
        }
      }

      maxY = up > maxY ? up : maxY;
      minY = down < minY ? down : minY;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            fromY: down,
            toY: up,
            width: weeks.length > 16 ? 8 : 16,
            borderRadius: BorderRadius.zero,
            rodStackItems: stack,
            color: Colors.transparent,
          ),
        ],
      ));
    }

    final interval = niceInterval(maxY - minY, emptyFallback: 100);
    final labelEvery = (weeks.length / 4).ceil().clamp(1, weeks.length);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.05,
          minY: minY * 1.05,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: 0,
              color: theme.colorScheme.outline,
              strokeWidth: 1,
            ),
          ]),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  value.round().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      shortDate(weeks[i].weekStart),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colour key for the stacked bars.
class CategoryLegend extends StatelessWidget {
  const CategoryLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final category in ActivityCategory.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: categoryPresentation[category]!.colour,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(category.label, style: theme.textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
