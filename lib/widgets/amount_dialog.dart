import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/week.dart';
import '../scoring/scoring.dart';
import 'day_selector.dart';

/// The outcome of editing an entry: its amount, and the day it belongs to.
class AmountEdit {
  const AmountEdit({required this.value, required this.day});

  final double value;

  /// Local midnight on the chosen day, or null when the day was not editable.
  final DateTime? day;
}

/// Prompts for an amount in [category]'s own unit, and optionally the day.
///
/// Returns the edit, or null if the user cancelled. Used to correct an entry
/// that was logged wrong - a mis-tapped preset, the wrong duration, or the
/// right activity recorded against the wrong day.
///
/// Passing [week] adds a day picker; [today] bounds it, since nothing can be
/// logged into the future.
Future<AmountEdit?> showAmountDialog(
  BuildContext context, {
  required ActivityCategory category,
  required double initialValue,
  required String title,
  WeekRange? week,
  DateTime? initialDay,
  DateTime? today,
}) {
  return showDialog<AmountEdit>(
    context: context,
    builder: (context) => _AmountDialog(
      category: category,
      initialValue: initialValue,
      title: title,
      week: week,
      initialDay: initialDay,
      today: today,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.category,
    required this.initialValue,
    required this.title,
    this.week,
    this.initialDay,
    this.today,
  });

  final ActivityCategory category;
  final double initialValue;
  final String title;
  final WeekRange? week;
  final DateTime? initialDay;
  final DateTime? today;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _trim(widget.initialValue),
  );
  late DateTime? _day = widget.initialDay;
  bool _valid = true;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final parsed = double.tryParse(_controller.text.trim());
      final valid = parsed != null && parsed > 0;
      if (valid != _valid) setState(() => _valid = valid);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) return;
    Navigator.of(context).pop(AmountEdit(value: parsed, day: _day));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHours = widget.category.unit == ActivityUnit.hours;
    final week = widget.week;
    final today = widget.today;
    final day = _day;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: isHours ? 'Hours' : 'Minutes',
              suffixText: isHours ? 'h' : 'min',
            ),
          ),
          if (week != null && today != null && day != null) ...[
            const SizedBox(height: 20),
            Text(
              'Day · ${dayLabel(day, today)}',
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
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
