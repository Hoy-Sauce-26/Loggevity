import 'curves.dart';
import 'interpolation.dart';
import 'models.dart';

/// Deterministic, dependency-free implementation of the Loggevity scoring
/// model. Every output is a pure function of [WeeklyTotals].
class HealthScoreCalculator {
  const HealthScoreCalculator();

  /// Converts one night's raw sleep into "adjusted hours", the currency the
  /// sleep sub-score is denominated in.
  ///
  /// Under-sleep is penalised at 2x the shortfall and over-sleep at 2x the
  /// excess, so both tails fall away twice as fast as they accrue. The result
  /// is intentionally unbounded below: a zero-hour night scores -7.5.
  static double adjustedSleepHours(double rawHours) {
    if (rawHours < 7.5) return 2 * rawHours - 7.5;
    if (rawHours <= 9.0) return 7.5;
    return 7.5 - 2 * (rawHours - 9.0);
  }

  /// Scores a week.
  ///
  /// [daysElapsed] is how far into the week the user is (1-7). Under
  /// [ScoreBasis.fullWeek] it affects nothing; under [ScoreBasis.pace] every
  /// target shrinks proportionally so a partial week reads as a projection.
  ScoreResult calculate(
    WeeklyTotals totals, {
    int daysElapsed = 7,
    ScoreBasis basis = ScoreBasis.fullWeek,
  }) {
    final days = daysElapsed.clamp(1, 7);
    // Fraction of the week the targets should cover.
    final f = basis == ScoreBasis.pace ? days / 7.0 : 1.0;

    // Under `pace`, project each raw input up to its full-week equivalent and
    // then apply the ordinary full-week formulas.
    double project(double raw) => raw / f;

    double linear(double raw, double weeklyTarget) {
      final v = project(raw) / weeklyTarget * 10.0;
      return v > 10.0 ? 10.0 : v;
    }

    final adjustedSleep = totals.sleepHoursPerNight
        .fold(0.0, (sum, h) => sum + adjustedSleepHours(h));
    final sleepScore = adjustedSleep / (kSleepWeeklyTarget * f) * 10.0;

    final categories = <CategoryScore>[
      CategoryScore(
        ActivityCategory.moderatePA,
        interpolate(project(totals.moderateMinutes), modX, modY),
      ),
      CategoryScore(
        ActivityCategory.vigorousPA,
        interpolate(project(totals.vigorousMinutes), vigX, vigY),
      ),
      CategoryScore(
        ActivityCategory.resistance,
        interpolate(project(totals.resistanceMinutes), resX, resY),
      ),
      CategoryScore(
        ActivityCategory.flexibility,
        linear(totals.flexibilityMinutes, kFlexWeeklyTargetMinutes),
      ),
      CategoryScore(
        ActivityCategory.nature,
        linear(totals.natureMinutes, kNatureWeeklyTargetMinutes),
      ),
      CategoryScore(
        ActivityCategory.socializing,
        linear(totals.socializingHours, kSocialWeeklyTargetHours),
      ),
      CategoryScore(
        ActivityCategory.sleep,
        sleepScore > 10.0 ? 10.0 : sleepScore,
      ),
    ];

    return ScoreResult(
      categories: categories,
      basis: basis,
      daysElapsed: days,
      adjustedSleepHours: adjustedSleep,
    );
  }
}
