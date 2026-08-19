import 'package:flutter/material.dart';

import '../scoring/scoring.dart';

/// A single tap target in the quick-log sheet.
class QuickLogOption {
  const QuickLogOption(this.label, this.value);

  final String label;

  /// In the category's own unit - minutes or hours.
  final double value;
}

/// Icon, and the increments offered for one-tap logging.
///
/// The increments are deliberately coarse: the point of the sheet is to log a
/// walk in one tap on the way through the door, not to record it precisely.
class CategoryPresentation {
  const CategoryPresentation(this.icon, this.quickOptions);

  final IconData icon;
  final List<QuickLogOption> quickOptions;
}

const categoryPresentation = <ActivityCategory, CategoryPresentation>{
  ActivityCategory.moderatePA: CategoryPresentation(
    Icons.directions_walk,
    [
      QuickLogOption('+15m', 15),
      QuickLogOption('+30m', 30),
      QuickLogOption('+45m', 45),
      QuickLogOption('+1h', 60),
    ],
  ),
  ActivityCategory.vigorousPA: CategoryPresentation(
    Icons.directions_run,
    [
      QuickLogOption('+10m', 10),
      QuickLogOption('+20m', 20),
      QuickLogOption('+30m', 30),
    ],
  ),
  ActivityCategory.resistance: CategoryPresentation(
    Icons.fitness_center,
    [
      QuickLogOption('+15m', 15),
      QuickLogOption('+30m', 30),
      QuickLogOption('+45m', 45),
    ],
  ),
  ActivityCategory.flexibility: CategoryPresentation(
    Icons.self_improvement,
    [
      QuickLogOption('+10m', 10),
      QuickLogOption('+15m', 15),
      QuickLogOption('+30m', 30),
    ],
  ),
  ActivityCategory.nature: CategoryPresentation(
    Icons.park_outlined,
    [
      QuickLogOption('+15m', 15),
      QuickLogOption('+30m', 30),
      QuickLogOption('+1h', 60),
    ],
  ),
  ActivityCategory.socializing: CategoryPresentation(
    Icons.people_outline,
    [
      QuickLogOption('+30m', 0.5),
      QuickLogOption('+1h', 1),
      QuickLogOption('+2h', 2),
      QuickLogOption('+3h', 3),
    ],
  ),
  // Sleep is a nightly figure rather than a running tally, so its options set
  // a night's length instead of nudging a total upward.
  ActivityCategory.sleep: CategoryPresentation(
    Icons.bedtime_outlined,
    [
      QuickLogOption('6h', 6),
      QuickLogOption('7h', 7),
      QuickLogOption('7.5h', 7.5),
      QuickLogOption('8h', 8),
      QuickLogOption('8.5h', 8.5),
      QuickLogOption('9h', 9),
    ],
  ),
};

/// Renders a raw total in its own unit: `524 min`, `22h`, `7.5h`.
String formatAmount(ActivityCategory category, double value) {
  if (category.unit == ActivityUnit.minutes) {
    return '${_trim(value)} min';
  }
  return '${_trim(value)}h';
}

String _trim(double v) {
  final rounded = (v * 10).roundToDouble() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

/// Sub-scores print to one decimal, with an explicit sign when negative so a
/// penalty never reads as a small positive.
String formatSubScore(double subScore) =>
    '${subScore.toStringAsFixed(1)}/10';
