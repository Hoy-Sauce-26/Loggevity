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
  const CategoryPresentation(this.icon, this.colour, this.quickOptions);

  final IconData icon;

  /// Identity colour for charts. Fixed rather than theme-derived: seven
  /// categories need to stay distinguishable from each other, which a Material
  /// scheme's handful of roles cannot guarantee. Mid-tone values chosen to
  /// hold contrast against both light and dark surfaces.
  final Color colour;

  final List<QuickLogOption> quickOptions;
}

const categoryPresentation = <ActivityCategory, CategoryPresentation>{
  ActivityCategory.moderatePA: CategoryPresentation(
    Icons.directions_walk,
    Color(0xFF2E8B78),
    [QuickLogOption('+15m', 15), QuickLogOption('+30m', 30)],
  ),
  ActivityCategory.vigorousPA: CategoryPresentation(
    Icons.directions_run,
    Color(0xFFE0784A),
    [QuickLogOption('+15m', 15), QuickLogOption('+30m', 30)],
  ),
  ActivityCategory.resistance: CategoryPresentation(
    Icons.fitness_center,
    Color(0xFF6272C4),
    [QuickLogOption('+15m', 15), QuickLogOption('+30m', 30)],
  ),
  ActivityCategory.flexibility: CategoryPresentation(
    Icons.self_improvement,
    Color(0xFF9B72C6),
    [QuickLogOption('+15m', 15), QuickLogOption('+30m', 30)],
  ),
  ActivityCategory.nature: CategoryPresentation(
    Icons.park_outlined,
    Color(0xFF6BA557),
    [QuickLogOption('+30m', 30), QuickLogOption('+1h', 60)],
  ),
  ActivityCategory.socializing: CategoryPresentation(
    Icons.people_outline,
    Color(0xFFD3A03F),
    [QuickLogOption('+30m', 0.5), QuickLogOption('+1h', 1)],
  ),
  // Sleep is a nightly figure rather than a running tally, so its options set
  // a night's length instead of nudging a total upward.
  ActivityCategory.sleep: CategoryPresentation(
    Icons.bedtime_outlined,
    Color(0xFF4E93AC),
    [
      QuickLogOption('7h', 7),
      QuickLogOption('8h', 8),
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
String formatSubScore(double subScore) => '${subScore.toStringAsFixed(1)}/10';
