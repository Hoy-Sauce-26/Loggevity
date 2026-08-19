import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/scoring.dart';
import 'category_presentation.dart';

/// Opens the intra-day quick-log sheet.
Future<void> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const QuickLogSheet(),
  );
}

/// One-tap logging for every category.
///
/// The sheet stays open after a tap so several things can be logged in a row,
/// and the most recent one can always be taken back. Undo lives inside the
/// sheet rather than in a SnackBar: a SnackBar renders behind the sheet's
/// modal barrier, which swallows the tap and closes the sheet instead of
/// undoing anything.
class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key});

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

typedef _LastLog = ({int id, String label});

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  _LastLog? _lastLog;

  Future<void> _log(ActivityCategory category, QuickLogOption option) async {
    final id = await ref
        .read(metricsRepositoryProvider)
        .log(category: category, value: option.value);
    if (!mounted) return;
    setState(() {
      _lastLog = (id: id, label: '${category.label} ${option.label}');
    });
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
    final theme = Theme.of(context);
    final metrics = ref.watch(currentWeekProvider).value;
    final last = _lastLog;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Log activity', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Tap to add to this week.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (last != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Added ${last.label}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                  TextButton(onPressed: _undo, child: const Text('Undo')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final category in ActivityCategory.values)
            _CategoryRow(
              category: category,
              loggedThisWeek: metrics?.totals.rawFor(category) ?? 0,
              nights: category == ActivityCategory.sleep
                  ? metrics?.totals.sleepHoursPerNight.length ?? 0
                  : null,
              onLog: (option) => _log(category, option),
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
  final ValueChanged<QuickLogOption> onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = categoryPresentation[category]!;
    final subtitle = nights == null
        ? formatAmount(category, loggedThisWeek)
        : '${formatAmount(category, loggedThisWeek)} · '
            '$nights ${nights == 1 ? 'night' : 'nights'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(presentation.icon,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(category.label, style: theme.textTheme.titleSmall),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in presentation.quickOptions)
                ActionChip(
                  label: Text(option.label),
                  onPressed: () => onLog(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
