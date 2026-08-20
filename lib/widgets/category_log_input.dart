import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scoring/scoring.dart';
import 'category_presentation.dart';

/// The logging control for one category: a text box for an exact amount, an
/// add button, and the category's presets.
///
/// Shared by the quick-log sheet and each category's detail sheet, so the two
/// cannot drift apart - the same units, validation, and presets apply wherever
/// something is logged.
class CategoryLogInput extends StatefulWidget {
  const CategoryLogInput({
    super.key,
    required this.category,
    required this.onLog,
  });

  final ActivityCategory category;

  /// Called with the amount and a short human label describing it.
  final void Function(double value, String label) onLog;

  @override
  State<CategoryLogInput> createState() => _CategoryLogInputState();
}

class _CategoryLogInputState extends State<CategoryLogInput> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final parsed = double.tryParse(_controller.text.trim());
      final valid = parsed != null && parsed > 0;
      if (valid != _canSubmit) setState(() => _canSubmit = valid);
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
    widget.onLog(parsed, formatAmount(widget.category, parsed));
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = categoryPresentation[widget.category]!;
    final isHours = widget.category.unit == ActivityUnit.hours;

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: isHours ? 'hours' : 'mins',
              suffixText: isHours ? 'h' : 'min',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // An explicit add button, because iOS numeric keypads have no return
        // key to submit with.
        IconButton.filledTonal(
          onPressed: _canSubmit ? _submit : null,
          icon: const Icon(Icons.add, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          tooltip: 'Add ${widget.category.label}',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final option in presentation.quickOptions)
                ActionChip(
                  label: Text(option.label),
                  onPressed: () => widget.onLog(option.value, option.label),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
