import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metrics_repository.dart';
import '../providers.dart';
import '../widgets/category_progress_tile.dart';
import '../widgets/quick_log_sheet.dart';
import '../widgets/score_ring.dart';

const _weekdayNames = <int, String>{
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(currentWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loggevity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Week starts on',
            onPressed: () => _pickWeekStart(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: weekAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load this week: $e')),
          data: (metrics) => _WeekView(metrics: metrics),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showQuickLogSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
    );
  }

  Future<void> _pickWeekStart(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final current = (await db.loadSettings()).weekStartDay;
    if (!context.mounted) return;

    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Week starts on'),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _weekdayNames.entries)
                  RadioListTile<int>(
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen != null && chosen != current) {
      await db.setWeekStartDay(chosen);
    }
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.metrics});

  final WeeklyMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = metrics.daysElapsed == 7;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        Center(
          child: ScoreRing(
            percent: metrics.pace.compositePercent,
            caption: complete
                ? 'Week complete'
                : 'On pace · day ${metrics.daysElapsed} of 7',
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _rangeLabel(metrics),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (metrics.isEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Nothing logged yet this week.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Text('This week', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '${metrics.full.compositePercent.toStringAsFixed(0)}% banked',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Bars track actual progress toward the full week, so they read as a
        // tally; the ring above answers the different question of whether the
        // week is on track so far.
        for (final score in metrics.full.categories)
          CategoryProgressTile(
            category: score.category,
            subScore: score.subScore,
            rawAmount: metrics.totals.rawFor(score.category),
          ),
      ],
    );
  }

  String _rangeLabel(WeeklyMetrics m) {
    final start = m.week.start;
    final end = m.week.lastDay;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final from = '${months[start.month - 1]} ${start.day}';
    final to = start.month == end.month
        ? '${end.day}'
        : '${months[end.month - 1]} ${end.day}';
    return '$from – $to';
  }
}
