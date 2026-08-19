import 'curves.dart';

/// Whether a score is measured against a whole week's targets or against the
/// portion of the week elapsed so far.
enum ScoreBasis {
  /// Raw progress toward the full-week target. A perfect Wednesday reads ~40%.
  fullWeek,

  /// Targets scaled to `daysElapsed`, so an on-track week reads near its
  /// eventual final score from day one.
  pace,
}

/// Raw weekly inputs. Minutes for the activity categories, hours for
/// socializing, and one raw (unadjusted) figure per night for sleep.
class WeeklyTotals {
  const WeeklyTotals({
    this.moderateMinutes = 0,
    this.vigorousMinutes = 0,
    this.resistanceMinutes = 0,
    this.flexibilityMinutes = 0,
    this.natureMinutes = 0,
    this.socializingHours = 0,
    this.sleepHoursPerNight = const <double>[],
  });

  final double moderateMinutes;
  final double vigorousMinutes;
  final double resistanceMinutes;
  final double flexibilityMinutes;
  final double natureMinutes;
  final double socializingHours;

  /// Raw hours slept per night, one entry per logged night. Never store the
  /// penalty-adjusted total here - the adjustment is derived.
  final List<double> sleepHoursPerNight;

  /// The raw logged amount for [c], in that category's own unit. Sleep
  /// returns total raw hours across the week, not the adjusted figure.
  double rawFor(ActivityCategory c) => switch (c) {
        ActivityCategory.moderatePA => moderateMinutes,
        ActivityCategory.vigorousPA => vigorousMinutes,
        ActivityCategory.resistance => resistanceMinutes,
        ActivityCategory.flexibility => flexibilityMinutes,
        ActivityCategory.nature => natureMinutes,
        ActivityCategory.socializing => socializingHours,
        ActivityCategory.sleep =>
          sleepHoursPerNight.fold(0.0, (a, b) => a + b),
      };
}

/// One category's contribution to the composite.
class CategoryScore {
  const CategoryScore(this.category, this.subScore);

  final ActivityCategory category;

  /// 0-10 nominal, but unbounded below: resistance bottoms at -9.0 and sleep
  /// at -10.0. Negatives are meaningful (overtraining, deprivation) and are
  /// deliberately not floored.
  final double subScore;

  /// Weighted points contributed to the composite numerator.
  double get points => subScore * category.weight;

  /// Share of this category's own ceiling, for progress indicators. Can be
  /// negative or (never, given clamped curves) above 1.0.
  double get fraction => subScore / 10.0;
}

/// Full breakdown of a scored week.
class ScoreResult {
  ScoreResult({
    required this.categories,
    required this.basis,
    required this.daysElapsed,
    required this.adjustedSleepHours,
  });

  final List<CategoryScore> categories;
  final ScoreBasis basis;
  final int daysElapsed;

  /// Penalty-adjusted sleep hours summed across logged nights.
  final double adjustedSleepHours;

  /// Weighted numerator, `sum(subScore * weight)`.
  double get totalPoints => categories.fold(0.0, (sum, c) => sum + c.points);

  /// Composite percentage. Tops out at 100.0 for a perfect week and can go
  /// negative for a severely deficient one.
  double get compositePercent => totalPoints / kMaxPoints * 100.0;

  CategoryScore operator [](ActivityCategory c) =>
      categories.firstWhere((s) => s.category == c);
}
