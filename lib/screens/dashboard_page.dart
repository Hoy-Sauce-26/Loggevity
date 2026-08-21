import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../scoring/scoring.dart';
import '../data/backup_service.dart';
import '../data/metrics_repository.dart';
import '../data/portability.dart';
import '../providers.dart';
import '../widgets/category_detail_sheet.dart';
import '../widgets/category_progress_tile.dart';
import '../widgets/fit_height.dart';
import '../widgets/locked_database_view.dart';
import '../widgets/quick_log_sheet.dart';
import '../widgets/score_ring.dart';
import 'analytics_page.dart';

/// Vertical space kept clear beneath the list for the floating Log button.
///
/// Reserving height rather than narrowing the last row means every row keeps
/// its full width. It also costs nothing when the page is short - the button
/// simply floats over space that was already empty - and only bites when
/// content reaches the bottom, which is exactly when clearance is needed.
const double _logButtonClearance = 76;

/// Height one category row needs. The rows are the content that must survive
/// on every screen, so they are budgeted first and the ring takes what is left.
const double _categoryRowHeight = 58;

/// Everything on the page that is neither the ring nor a category row:
/// padding, the week range, and the "This week" header.
const double _dashboardChrome = 92;

/// Headroom held back from the ring's share.
///
/// The estimates above are deliberately approximate - real row height moves
/// with the user's text-scale setting and the platform's font metrics. Without
/// slack the budget resolves to exactly the viewport height, so any
/// underestimate costs a whole row off the bottom.
const double _layoutSlack = 28;

enum _DataAction { exportJson, exportCsv, import }

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
    // Seals any week that ended while the app was closed. Watched rather than
    // fired-and-forgotten so a failure surfaces instead of silently leaving
    // history unwritten.
    ref.watch(sealOnLaunchProvider);

    // With no readable database there is nothing to log into, export, or
    // chart, so the controls that would only fail are withheld.
    final locked =
        weekAsync.hasError && isMissingDatabaseKey(weekAsync.error!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loggevity'),
        actions: locked ? const [] : [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Trends',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AnalyticsPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Week starts on',
            onPressed: () => _pickWeekStart(context, ref),
          ),
          PopupMenuButton<_DataAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Your data',
            onSelected: (action) => _runDataAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DataAction.exportJson,
                child: Text('Export as JSON'),
              ),
              PopupMenuItem(
                value: _DataAction.exportCsv,
                child: Text('Export as CSV'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _DataAction.import,
                child: Text('Import from file…'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: weekAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // A missing database key is not a transient load failure: it has its
          // own screen, because the raw exception gives the user nothing to
          // act on.
          error: (e, _) => isMissingDatabaseKey(e)
              ? const LockedDatabaseView()
              : Center(child: Text('Could not load this week: $e')),
          data: (metrics) => _WeekView(metrics: metrics),
        ),
      ),
      floatingActionButton: locked
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showQuickLogSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Log'),
            ),
    );
  }

  Future<void> _runDataAction(
    BuildContext context,
    WidgetRef ref,
    _DataAction action,
  ) async {
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case _DataAction.exportJson:
          await service.export(BackupFormat.json);
        case _DataAction.exportCsv:
          await service.export(BackupFormat.csv);
        case _DataAction.import:
          final outcome = await service.import();
          messenger.showSnackBar(
            SnackBar(content: Text(_importSummary(outcome))),
          );
      }
    } on ImportFormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("That file couldn't be read: ${e.message}")),
      );
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }

  /// Reports what actually happened, including the parts that did not work -
  /// a silent import leaves the user unsure whether their data arrived.
  static String _importSummary(ImportOutcome outcome) {
    final parts = <String>[];
    if (outcome.added > 0) {
      parts.add('Added ${outcome.added} '
          '${outcome.added == 1 ? 'entry' : 'entries'}');
    }
    if (outcome.skipped > 0) {
      parts.add('${outcome.skipped} already present');
    }
    if (outcome.errors.isNotEmpty) {
      parts.add('${outcome.errors.length} could not be read');
    }
    if (parts.isEmpty) return 'Nothing to import.';
    return parts.join(' · ');
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

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.metrics});

  final WeeklyMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FitHeight(
      builder: (context, constraints) {
        // Give the seven rows their space first, then let the ring have the
        // remainder. On a tall screen that is the full 220; on a short one the
        // ring shrinks rather than pushing Sleep off the bottom.
        final leftover = constraints.maxHeight -
            (_categoryRowHeight * ActivityCategory.values.length) -
            _dashboardChrome -
            _layoutSlack -
            (metrics.isEmpty ? 34 : 0);
        final diameter = leftover.clamp(120.0, 220.0);
        return _build(context, ref, diameter);
      },
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, double diameter) {
    final theme = Theme.of(context);
    final showsPace = ref.watch(ringShowsPaceProvider);
    final complete = metrics.daysElapsed == 7;
    // The ring shows one reading; the header shows the other, so both numbers
    // stay on screen whichever way the toggle is set.
    final ringScore = showsPace
        ? metrics.pace.compositePercent
        : metrics.full.compositePercent;
    final otherScore = showsPace
        ? metrics.full.compositePercent
        : metrics.pace.compositePercent;
    final otherLabel = showsPace ? 'banked' : 'on pace';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ScoreRing(
              diameter: diameter,
              percent: ringScore,
              caption: complete
                  ? (showsPace ? 'Week complete' : 'Banked')
                  : '${showsPace ? 'On pace' : 'Banked'} · '
                      'day ${metrics.daysElapsed} of 7',
              onTap: () =>
                  ref.read(databaseProvider).setRingShowsPace(!showsPace),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Text('This week', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${otherScore.toStringAsFixed(0)}% $otherLabel',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Bars track actual progress toward the full week, so they read as a
          // tally; the ring above answers the different question of whether the
          // week is on track so far.
          //
          ..._categoryRows(context, metrics),
        ],
      ),
    );
  }

  /// One full-width row per category, in order. Tapping one opens its
  /// day-by-day breakdown, which is also where entries are corrected.
  List<Widget> _categoryRows(BuildContext context, WeeklyMetrics metrics) {
    return [
      for (final score in metrics.full.categories)
        CategoryProgressTile(
          category: score.category,
          subScore: score.subScore,
          rawAmount: metrics.totals.rawFor(score.category),
          onTap: () => showCategoryDetailSheet(context, score.category),
        ),
      const SizedBox(height: _logButtonClearance),
    ];
  }

  String _rangeLabel(WeeklyMetrics m) {
    final start = m.week.start;
    final end = m.week.lastDay;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final from = '${months[start.month - 1]} ${start.day}';
    final to = start.month == end.month
        ? '${end.day}'
        : '${months[end.month - 1]} ${end.day}';
    return '$from – $to';
  }
}
