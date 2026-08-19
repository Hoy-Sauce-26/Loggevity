import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/week_sealer.dart';
import '../providers.dart';
import '../scoring/scoring.dart';
import '../widgets/charts/category_contribution_chart.dart';
import '../widgets/charts/score_trend_chart.dart';

enum AnalyticsWindow {
  fourWeeks(4, '4 weeks'),
  twelveWeeks(12, '12 weeks'),
  year(52, '1 year');

  const AnalyticsWindow(this.weeks, this.label);

  final int weeks;
  final String label;
}

class AnalyticsWindowNotifier extends Notifier<AnalyticsWindow> {
  @override
  AnalyticsWindow build() => AnalyticsWindow.twelveWeeks;

  void select(AnalyticsWindow window) => state = window;
}

final analyticsWindowProvider =
    NotifierProvider<AnalyticsWindowNotifier, AnalyticsWindow>(
  AnalyticsWindowNotifier.new,
);

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(analyticsWindowProvider);
    final snapshotsAsync = ref.watch(snapshotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: SafeArea(
        child: snapshotsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load history: $e')),
          data: (all) {
            final shown = _within(all, window);
            if (shown.isEmpty) return _Empty(hasAnyHistory: all.isNotEmpty);
            return _History(snapshots: shown, window: window);
          },
        ),
      ),
    );
  }

  /// Snapshots whose week falls inside the selected window.
  ///
  /// Filtered by date rather than by taking the last N rows, so a gap in
  /// logging reads as a gap instead of silently pulling older weeks forward.
  List<WeeklySnapshot> _within(
    List<WeeklySnapshot> all,
    AnalyticsWindow window,
  ) {
    if (all.isEmpty) return const [];
    final latest = all.last.weekStartDate;
    // Calendar arithmetic, not a Duration: subtracting days as a fixed span
    // drifts by an hour across a DST boundary, which would push the cutoff
    // past midnight and silently drop the oldest week in the window.
    final cutoff = DateTime(
      latest.year,
      latest.month,
      latest.day - 7 * (window.weeks - 1),
    );
    return all.where((s) => !s.weekStartDate.isBefore(cutoff)).toList();
  }
}

class _History extends ConsumerWidget {
  const _History({required this.snapshots, required this.window});

  final List<WeeklySnapshot> snapshots;
  final AnalyticsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scores = snapshots.map((s) => s.compositeScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        SegmentedButton<AnalyticsWindow>(
          segments: [
            for (final w in AnalyticsWindow.values)
              ButtonSegment(value: w, label: Text(w.label)),
          ],
          selected: {window},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(analyticsWindowProvider.notifier).select(s.first),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Stat(
              label: '${snapshots.length} '
                  '${snapshots.length == 1 ? 'week' : 'weeks'}',
              value: 'logged',
            ),
            _Stat(label: 'Average', value: '${average.toStringAsFixed(0)}%'),
            _Stat(label: 'Best', value: '${best.toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 24),
        Text('Composite score', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ScoreTrendChart(
          points: [
            for (final s in snapshots)
              TrendPoint(s.weekStartDate, s.compositeScore),
          ],
        ),
        const SizedBox(height: 32),
        Text('Where the points came from', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Weighted points, so bar height matches each category’s real '
          'share of the score.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        CategoryContributionChart(
          weeks: [
            for (final s in snapshots)
              ContributionWeek(s.weekStartDate, {
                for (final c in ActivityCategory.values) c: s.pointsFor(c),
              }),
          ],
        ),
        const SizedBox(height: 16),
        const CategoryLegend(),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasAnyHistory});

  final bool hasAnyHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          hasAnyHistory
              ? 'No completed weeks in this window.'
              : 'Trends appear once your first week is complete.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
