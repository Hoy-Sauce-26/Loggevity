import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scoring/scoring.dart';

/// Prompts for an amount in [category]'s own unit.
///
/// Returns the new value, or null if the user cancelled. Used to correct an
/// entry that was logged wrong - a mis-tapped preset, or the wrong duration.
Future<double?> showAmountDialog(
  BuildContext context, {
  required ActivityCategory category,
  required double initialValue,
  required String title,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _AmountDialog(
      category: category,
      initialValue: initialValue,
      title: title,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.category,
    required this.initialValue,
    required this.title,
  });

  final ActivityCategory category;
  final double initialValue;
  final String title;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _trim(widget.initialValue),
  );
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
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isHours = widget.category.unit == ActivityUnit.hours;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
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
