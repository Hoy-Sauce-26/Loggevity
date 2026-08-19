/// Category definitions and lookup curves.
///
/// Every curve below is a **score** curve (0-10 scale, and deliberately
/// unbounded below). They derive from hazard ratios in the source workbook as
/// `score = (1 - HR) / k * 10`, where `k` is the maximum achievable HR
/// reduction for that category. The HR columns themselves are *not* scores:
/// a HR of 1.0 means "no benefit" and maps to a score of 0.
library;

/// Unit in which a category's raw values are recorded.
enum ActivityUnit { minutes, hours }

/// The seven scored categories, with their composite weights.
///
/// Weights come from `Score Support!B24:B30`. The denominator for the
/// composite is `10 * sum(weights)` = 1690, i.e. vigorous activity is a
/// required category rather than bonus credit.
enum ActivityCategory {
  moderatePA('Moderate Activity', 40.0, ActivityUnit.minutes),
  vigorousPA('Vigorous Activity', 15.0, ActivityUnit.minutes),
  resistance('Resistance Training', 8.0, ActivityUnit.minutes),
  flexibility('Flexibility / Balance', 7.0, ActivityUnit.minutes),
  nature('Time in Nature', 15.0, ActivityUnit.minutes),
  socializing('Socializing', 50.0, ActivityUnit.hours),
  sleep('Sleep', 34.0, ActivityUnit.hours);

  const ActivityCategory(this.label, this.weight, this.unit);

  final String label;
  final double weight;
  final ActivityUnit unit;

  /// Maximum weighted points this category can contribute (10 x weight).
  double get maxPoints => weight * 10.0;
}

/// Sum of all category weights (169.0).
final double kTotalWeight =
    ActivityCategory.values.fold(0.0, (a, c) => a + c.weight);

/// Composite denominator (1690.0).
final double kMaxPoints = kTotalWeight * 10.0;

// --- Curve grids (weekly minutes -> score) ---

/// HR 1.00 -> 0.60, so k = 0.40.
const modX = <double>[0, 75, 160, 250, 900, 10080];
const modY = <double>[0, 2, 4.5, 5.5, 10, 10];

/// HR 1.00 -> 0.85, so k = 0.15. Horseshoe: benefit peaks at 215 min.
const vigX = <double>[0, 100, 215, 900];
const vigY = <double>[0, 8.666666666666666, 10, 6.666666666666667];

/// HR 1.00 -> 0.80, so k = 0.20. Peaks across 45-60 min, then declines
/// through zero at 140 min into genuine overtraining penalty at 200 min.
const resX = <double>[0, 15, 22, 45, 60, 80, 100, 140, 160, 200];
const resY = <double>[0, 4, 6.5, 10, 10, 8, 6.5, 0, -2.5, -9];

// --- Linear targets (value that earns a full 10.0 over a whole week) ---

const double kFlexWeeklyTargetMinutes = 45.0;
const double kNatureWeeklyTargetMinutes = 120.0;
const double kSocialWeeklyTargetHours = 21.0;

/// Adjusted sleep hours earned by a single ideal night.
const double kSleepIdealNightly = 7.5;

/// Adjusted sleep hours for a perfect week (7 x 7.5).
const double kSleepWeeklyTarget = kSleepIdealNightly * 7;
