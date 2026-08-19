import 'package:flutter/material.dart';

/// Radial gauge for the week-to-date composite score.
///
/// The score is a percentage that can legitimately fall below zero - a week of
/// heavy overtraining on no sleep scores negative - so the arc clamps at empty
/// while the readout keeps the true figure and switches to the error colour.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.percent,
    required this.caption,
  });

  final double percent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = percent < 0;
    final colour =
        negative ? theme.colorScheme.error : theme.colorScheme.primary;
    final progress = (percent / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colour),
              strokeCap: StrokeCap.round,
              semanticsLabel: 'Composite health score',
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: negative ? theme.colorScheme.error : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
