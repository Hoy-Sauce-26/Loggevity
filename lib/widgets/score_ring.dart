import 'package:flutter/material.dart';

/// Radial gauge for the week-to-date composite score.
///
/// The score is a percentage that can legitimately fall below zero - a week of
/// heavy overtraining on no sleep scores negative - so the arc clamps at empty
/// while the readout keeps the true figure and switches to the error colour.
///
/// [diameter] is set by the caller from the space actually left over, so the
/// ring gives way on short screens instead of pushing content off the bottom.
/// Everything inside scales with it.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.percent,
    required this.caption,
    this.diameter = 220,
  });

  final double percent;
  final String caption;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = percent < 0;
    final colour =
        negative ? theme.colorScheme.error : theme.colorScheme.primary;
    final progress = (percent / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: diameter,
            height: diameter,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: (diameter * 0.064).clamp(8.0, 14.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colour),
              strokeCap: StrokeCap.round,
              semanticsLabel: 'Composite health score',
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: diameter * 0.16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: (diameter * 0.16).clamp(22.0, 36.0),
                      fontWeight: FontWeight.bold,
                      color: negative ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Flexible plus scaleDown so a long caption gives way inside a
                // small ring instead of overflowing it.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: (diameter * 0.062).clamp(10.0, 14.0),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
