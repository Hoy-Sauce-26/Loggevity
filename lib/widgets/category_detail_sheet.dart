import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/metrics_repository.dart';
import '../data/week.dart';
import '../providers.dart';
import '../scoring/scoring.dart';
import 'category_log_input.dart';
import 'category_presentation.dart';
import 'charts/chart_format.dart';
import 'amount_dialog.dart';
import 'day_selector.dart';

/// Opens the day-by-day breakdown for one category.
Future<void> showCategoryDetailSheet(
  BuildContext context,
  ActivityCategory category,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => CategoryDetailSheet(category: category),
  );
}

/// A week of one category, broken down by day and editable entry by entry.
///
/// Every category is stored per entry with a local date, so all seven get a
/// daily breakdown - sleep is only special in that the scoring model consumes
/// it per night. This is also the only place a mis-tapped amount can be
/// corrected, so the entry list is the point of the screen, not the chart.
class CategoryDetailSheet extends ConsumerStatefulWidget {
  const CategoryDetailSheet({super.key, required this.category});

  final ActivityCategory category;

  @override
  ConsumerState<CategoryDetailSheet> createState() =>
      _CategoryDetailSheetState();
}

class _CategoryDetailSheetState extends ConsumerState<CategoryDetailSheet> {
  /// Which day a new log from this sheet lands on. Null means today.
  DateTime? _day;

  DateTime get _today {
    final now = ref.read(metricsRepositoryProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _selectedDay => _day ?? _today;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final theme = Theme.of(context);
    final week = ref.watch(currentWeekRangeProvider);
    final today = _today;
    final day = _selectedDay;
    final entriesAsync = ref.watch(categoryEntriesProvider(category));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: entriesAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(child: Text('Could not load entries: $e')),
        ),
        data: (entries) {
          final daily = MetricsRepository.dailyTotals(week, entries);
          final total = daily.fold(0.0, (a, b) => a + b);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Row(
                children: [
                  Icon(categoryPresentation[category]!.icon,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(category.label,
                        style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    formatAmount(category, total),
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'This week, day by day · '
                '${category.unit == ActivityUnit.hours ? 'hours' : 'minutes'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _DailyChart(week: week, daily: daily, category: category),
              const SizedBox(height: 18),
              // The same control as the quick-log sheet, narrowed to this one
              // category, so a correction can be made without going back out
              // to the main screen. It sits between the chart and the entry
              // list, next to the entries a new log will join.
              Text(
                'Add to ${dayLabel(day, today)}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              DaySelector(
                week: week,
                selected: localDateKey(day),
                today: today,
                onSelected: (picked) => setState(() => _day = picked),
              ),
              const SizedBox(height: 10),
              CategoryLogInput(
                category: category,
                onLog: (value, _) {
                  final now = ref.read(metricsRepositoryProvider).now();
                  ref.read(metricsRepositoryProvider).log(
                        category: category,
                        value: value,
                        occurredAt: DateTime(day.year, day.month, day.day,
                            now.hour, now.minute),
                      );
                },
              ),
              const SizedBox(height: 20),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nothing logged for this category yet.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ..._entryList(context, ref, week, entries, theme, today),
            ],
          );
        },
      ),
    );
  }

  /// Entries grouped under a heading per day.
  List<Widget> _entryList(
    BuildContext context,
    WidgetRef ref,
    WeekRange week,
    List<DailyEntry> entries,
    ThemeData theme,
    DateTime today,
  ) {
    final category = widget.category;
    final byDay = <String, List<DailyEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.localDate, () => []).add(e);
    }

    final widgets = <Widget>[];
    for (final day in week.days) {
      final key = localDateKey(day);
      final forDay = byDay[key];
      if (forDay == null || forDay.isEmpty) continue;

      final dayTotal = forDay.fold(0.0, (a, e) => a + e.value);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Text('${shortWeekday(day)} ${shortDate(day)}',
                style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              formatAmount(category, dayTotal),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ));
      for (final entry in forDay) {
        widgets.add(_EntryRow(
          category: category,
          entry: entry,
          week: week,
          today: today,
        ));
      }
    }
    return widgets;
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.category,
    required this.entry,
    required this.week,
    required this.today,
  });

  final ActivityCategory category;
  final DailyEntry entry;
  final WeekRange week;
  final DateTime today;

  String get _time {
    final local = entry.occurredAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final local = entry.occurredAt.toLocal();
    final updated = await showAmountDialog(
      context,
      category: category,
      initialValue: entry.value,
      title: 'Edit ${category.label}',
      week: week,
      initialDay: DateTime(local.year, local.month, local.day),
      today: today,
    );
    if (updated == null) return;
    await ref.read(metricsRepositoryProvider).updateEntry(
          entry.id,
          value: updated.value,
          day: updated.day,
        );
  }

  Future<void> _delete(WidgetRef ref) =>
      ref.read(metricsRepositoryProvider).deleteEntry(entry.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _edit(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(_time,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                entry.note?.isNotEmpty == true
                    ? entry.note!
                    : formatAmount(category, entry.value),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (entry.note?.isNotEmpty == true) ...[
              Text(formatAmount(category, entry.value),
                  style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              onPressed: () => _edit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({
    required this.week,
    required this.daily,
    required this.category,
  });

  final WeekRange week;
  final List<double> daily;
  final ActivityCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHours = category.unit == ActivityUnit.hours;
    final peak = daily.fold(0.0, (a, b) => b > a ? b : a);
    // Round the ceiling up to a whole number of gridlines so the top line and
    // the top label land on the same value.
    final headroom = peak <= 0 ? (isHours ? 8.0 : 60.0) : peak * 1.15;
    final interval = niceInterval(headroom, emptyFallback: isHours ? 2 : 15);
    final maxY = (headroom / interval).ceil() * interval;

    String label(double value) =>
        interval < 1 ? value.toStringAsFixed(1) : value.round().toString();

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          // Without a scale the bars only show relative size, which says
          // nothing about whether a day was 10 minutes or 100.
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              // maxY is the plot boundary, so FlGridData draws no line there.
              // The topmost label would otherwise float without a rule to sit
              // on, leaving the tallest bars unbounded to the eye.
              top: BorderSide(color: theme.colorScheme.outlineVariant),
              bottom: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                formatAmount(category, daily[group.x]),
                theme.textTheme.labelSmall ?? const TextStyle(),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 38,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    label(value),
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= week.days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(shortWeekday(week.days[i]),
                        style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < daily.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: daily[i],
                    width: 18,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                    // Theme primary, not the category's chart identity
                    // colour: only one category is shown here, so the
                    // identity carries no information and would just clash
                    // with the palette.
                    color: daily[i] > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
