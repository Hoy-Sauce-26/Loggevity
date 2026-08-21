import 'package:flutter/material.dart';

import '../data/week.dart';
import 'charts/chart_format.dart';

/// Picks which day of [week] a log belongs to.
///
/// Logging is not always same-day: a night's sleep is remembered the following
/// afternoon, and a walk on Saturday might only get entered on Sunday. Without
/// this, a forgotten entry has to be added to today, which both mis-credits
/// today and leaves the day it actually happened empty - and for sleep, scored
/// as a missing night.
///
/// Days later than [today] are disabled: nothing can have happened yet.
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.week,
    required this.selected,
    required this.today,
    required this.onSelected,
  });

  final WeekRange week;

  /// The currently chosen day, as a local `YYYY-MM-DD` key.
  final String selected;

  /// Local midnight today. Days after this cannot be chosen.
  final DateTime today;

  final void Function(DateTime day) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayKey = localDateKey(today);

    return Row(
      children: [
        for (final day in week.days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DayChip(
                label: shortWeekday(day).substring(0, 1),
                dayOfMonth: day.day,
                selected: localDateKey(day) == selected,
                // Comparing keys rather than DateTimes: both are local
                // midnights, but a DST shift can leave them unequal instants.
                enabled: localDateKey(day).compareTo(todayKey) <= 0,
                onTap: () => onSelected(day),
                theme: theme,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.dayOfMonth,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final int dayOfMonth;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final foreground = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.38)
        : selected
            ? scheme.onPrimary
            : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              ),
              Text(
                '$dayOfMonth',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Today`, `Yesterday`, or `Sat Aug 15` - names the day a log will land on.
String dayLabel(DateTime day, DateTime today) {
  final key = localDateKey(day);
  if (key == localDateKey(today)) return 'Today';
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (key == localDateKey(yesterday)) return 'Yesterday';
  return '${shortWeekday(day)} ${shortDate(day)}';
}
