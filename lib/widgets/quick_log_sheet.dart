import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/week.dart';
import '../providers.dart';
import '../scoring/scoring.dart';
import 'category_log_input.dart';
import 'category_presentation.dart';
import 'day_selector.dart';
import 'fit_height.dart';

/// Opens the intra-day quick-log sheet.
Future<void> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Without this the sheet extends under the status bar and, on Android,
    // under the system navigation bar - which is what cut the Sleep row off.
    useSafeArea: true,
    builder: (_) => const QuickLogSheet(),
  );
}

/// Logging for every category: type an exact amount, or tap a preset.
///
/// The text box comes first because it is the general case - presets only
/// cover the handful of amounts that recur. The sheet stays open after each
/// entry so several things can be logged in a row, and the most recent one can
/// always be taken back. Undo lives inside the sheet rather than in a
/// SnackBar: a SnackBar renders behind the sheet's modal barrier, which
/// swallows the tap and closes the sheet instead of undoing anything.
class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key});

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

typedef _LastLog = ({int id, String label});

/// Comfortable spacing between category rows. Fixed rather than computed:
/// [FitHeight] shrinks the sheet if this does not fit, so there is nothing to
/// estimate.
const double _rowGap = 8;

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  _LastLog? _lastLog;

  /// Local midnight on the day being logged into. Defaults to today; the day
  /// picker moves it so something remembered late still lands on the day it
  /// happened.
  DateTime? _day;

  DateTime get _today {
    final now = ref.read(metricsRepositoryProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _selectedDay => _day ?? _today;

  Future<void> _log(
    ActivityCategory category,
    double value,
    String label,
  ) async {
    if (value <= 0) return;
    final now = ref.read(metricsRepositoryProvider).now();
    final day = _selectedDay;
    // Keep the current time of day on a back-dated entry: only the date
    // decides scoring, and a real clock time keeps the entry list ordered
    // sensibly rather than stacking everything at midnight.
    final occurredAt =
        DateTime(day.year, day.month, day.day, now.hour, now.minute);
    final id = await ref
        .read(metricsRepositoryProvider)
        .log(category: category, value: value, occurredAt: occurredAt);
    if (!mounted) return;
    final suffix = localDateKey(day) == localDateKey(_today)
        ? ''
        : ' on ${dayLabel(day, _today)}';
    setState(
        () => _lastLog = (id: id, label: '${category.label} $label$suffix'));
  }

  Future<void> _undo() async {
    final last = _lastLog;
    if (last == null) return;
    await ref.read(metricsRepositoryProvider).deleteEntry(last.id);
    if (!mounted) return;
    setState(() => _lastLog = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard so the field being typed into stays
      // visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The sheet is anchored to the physical bottom of the screen, so on
          // Android it runs underneath the navigation bar. `useSafeArea` only
          // insets the top. Reserve the bottom inset explicitly, and take it
          // out of the height budget too. Zero where the platform (or an
          // enclosing SafeArea) has already accounted for it.
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              // The cap has to sit outside FitHeight: inside, it would clamp
              // the content before it could be measured, and the scaling would
              // never trigger. Leaves a sliver of the dashboard visible.
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - bottomInset) * 0.94,
              ),
              child: FitHeight(builder: (context, _) => _build(context)),
            ),
          );
        },
      ),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = ref.watch(currentWeekProvider).value;
    final week = ref.watch(currentWeekRangeProvider);
    final today = _today;
    final day = _selectedDay;
    final last = _lastLog;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Log activity', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (last != null)
                TextButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Undo'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          Text(
            last == null
                ? 'Logging to ${dayLabel(day, today)} · '
                    'type an amount, or tap a preset.'
                : 'Added ${last.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: last == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          // Above the categories, because it applies to all of them: whichever
          // row is used next, it lands on this day.
          DaySelector(
            week: week,
            selected: localDateKey(day),
            today: today,
            // A day change invalidates the undo target's description, and the
            // entry it points at is no longer the obvious thing to take back.
            onSelected: (picked) => setState(() {
              _day = picked;
              _lastLog = null;
            }),
          ),
          const SizedBox(height: 4),
          for (final category in ActivityCategory.values)
            _CategoryRow(
              category: category,
              loggedThisWeek: metrics?.totals.rawFor(category) ?? 0,
              nights: category == ActivityCategory.sleep
                  ? metrics?.totals.sleepHoursPerNight.length ?? 0
                  : null,
              onLog: (value, label) => _log(category, value, label),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.loggedThisWeek,
    required this.onLog,
    this.nights,
  });

  final ActivityCategory category;
  final double loggedThisWeek;
  final int? nights;
  final void Function(double value, String label) onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = nights == null
        ? formatAmount(category, loggedThisWeek)
        : '${formatAmount(category, loggedThisWeek)} · '
            '$nights ${nights == 1 ? 'night' : 'nights'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryPresentation[category]!.icon,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category.label, style: theme.textTheme.labelLarge),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CategoryLogInput(category: category, onLog: onLog),
        ],
      ),
    );
  }
}
