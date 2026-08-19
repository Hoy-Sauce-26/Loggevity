import 'package:loggevity/scoring/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

const calc = HealthScoreCalculator();

/// "Baseline Week 1" - the seven days on the `Tracker` sheet of the source
/// workbook (2026-07-06 Mon through 2026-07-12 Sun).
const baseline = WeeklyTotals(
  moderateMinutes: 524,
  vigorousMinutes: 0,
  resistanceMinutes: 50,
  flexibilityMinutes: 50,
  natureMinutes: 136,
  socializingHours: 22,
  sleepHoursPerNight: [9.0, 9.0, 8.5, 8.75, 8.0, 7.75, 7.25],
);

void main() {
  group('Baseline Week 1', () {
    final r = calc.calculate(baseline);

    test('sub-scores match the spreadsheet row-for-row', () {
      expect(
          r[ActivityCategory.moderatePA].subScore, closeTo(7.396923077, 1e-9));
      expect(r[ActivityCategory.vigorousPA].subScore, 0.0);
      expect(r[ActivityCategory.resistance].subScore, 10.0);
      expect(r[ActivityCategory.flexibility].subScore, 10.0);
      expect(r[ActivityCategory.nature].subScore, 10.0);
      expect(r[ActivityCategory.socializing].subScore, 10.0);
      expect(r[ActivityCategory.sleep].subScore, closeTo(9.904761905, 1e-9));
    });

    test('raw sleep is compressed to 52.0 adjusted hours', () {
      // 58.25 raw hours across the seven nights.
      expect(baseline.sleepHoursPerNight.reduce((a, b) => a + b), 58.25);
      expect(r.adjustedSleepHours, closeTo(52.0, 1e-9));
    });

    test('composite is 84.77%', () {
      expect(r.totalPoints, closeTo(1432.638828, 1e-6));
      expect(r.compositePercent, closeTo(84.77, 0.005));
    });

    test('adding 200 min of vigorous activity gives 93.49%', () {
      final r2 = calc.calculate(const WeeklyTotals(
        moderateMinutes: 524,
        vigorousMinutes: 200,
        resistanceMinutes: 50,
        flexibilityMinutes: 50,
        natureMinutes: 136,
        socializingHours: 22,
        sleepHoursPerNight: [9.0, 9.0, 8.5, 8.75, 8.0, 7.75, 7.25],
      ));
      expect(
          r2[ActivityCategory.vigorousPA].subScore, closeTo(9.826086957, 1e-9));
      expect(r2.compositePercent, closeTo(93.49, 0.005));
    });
  });

  group('weights and denominator', () {
    test('weights sum to 169 and the denominator is 1690', () {
      expect(kTotalWeight, 169.0);
      expect(kMaxPoints, 1690.0);
    });

    test('a perfect week is exactly 100%', () {
      final r = calc.calculate(const WeeklyTotals(
        moderateMinutes: 900,
        vigorousMinutes: 215,
        resistanceMinutes: 50,
        flexibilityMinutes: 45,
        natureMinutes: 120,
        socializingHours: 21,
        sleepHoursPerNight: [8, 8, 8, 8, 8, 8, 8],
      ));
      expect(r.compositePercent, closeTo(100.0, 1e-9));
    });
  });

  group('curves derive from hazard ratios', () {
    // score = (1 - HR) / k * 10
    double fromHr(double hr, double k) => (1 - hr) / k * 10;

    test('moderate PA, k = 0.40', () {
      const hr = [1.0, 0.92, 0.82, 0.78, 0.6, 0.6];
      for (var i = 0; i < hr.length; i++) {
        expect(modY[i], closeTo(fromHr(hr[i], 0.40), 1e-9));
      }
    });

    test('vigorous PA, k = 0.15', () {
      const hr = [1.0, 0.87, 0.85, 0.9];
      for (var i = 0; i < hr.length; i++) {
        expect(vigY[i], closeTo(fromHr(hr[i], 0.15), 1e-9));
      }
    });

    test('resistance, k = 0.20', () {
      // Index 7 (140 min) is excluded: the workbook's HR cell there holds a
      // placeholder 0.0, while its Score cell holds the authoritative 0.0.
      const hr = [1.0, 0.92, 0.87, 0.8, 0.8, 0.84, 0.87, null, 1.05, 1.18];
      for (var i = 0; i < hr.length; i++) {
        if (hr[i] == null) continue;
        expect(resY[i], closeTo(fromHr(hr[i]!, 0.20), 1e-9));
      }
      expect(resY[7], 0.0);
    });
  });

  group('interpolation guards', () {
    test('clamps below the first anchor', () {
      expect(interpolate(-50, modX, modY), 0.0);
      expect(interpolate(0, resX, resY), 0.0);
    });

    test('clamps above the last anchor instead of extrapolating', () {
      expect(interpolate(99999, modX, modY), 10.0);
      expect(interpolate(5000, vigX, vigY), closeTo(6.666666667, 1e-9));
      expect(interpolate(300, resX, resY), -9.0);
    });

    test('hits every anchor exactly', () {
      for (var i = 0; i < resX.length; i++) {
        expect(interpolate(resX[i], resX, resY), closeTo(resY[i], 1e-12));
      }
    });

    test('resistance peaks across the 45-60 plateau and falls through zero',
        () {
      expect(interpolate(45, resX, resY), 10.0);
      expect(interpolate(52, resX, resY), 10.0);
      expect(interpolate(60, resX, resY), 10.0);
      expect(interpolate(140, resX, resY), 0.0);
      expect(interpolate(200, resX, resY), -9.0);
    });
  });

  group('sleep penalties', () {
    test('the 7.5-9.0h band is flat', () {
      for (final h in [7.5, 8.0, 8.5, 9.0]) {
        expect(HealthScoreCalculator.adjustedSleepHours(h), 7.5);
      }
    });

    test('under-sleep is penalised at 2x the shortfall', () {
      expect(HealthScoreCalculator.adjustedSleepHours(7.25), 7.0);
      expect(HealthScoreCalculator.adjustedSleepHours(6.0), 4.5);
      expect(HealthScoreCalculator.adjustedSleepHours(3.75), 0.0);
      expect(HealthScoreCalculator.adjustedSleepHours(0.0), -7.5);
    });

    test('over-sleep is penalised at 2x the excess', () {
      expect(HealthScoreCalculator.adjustedSleepHours(9.5), 6.5);
      expect(HealthScoreCalculator.adjustedSleepHours(11.0), 3.5);
      expect(HealthScoreCalculator.adjustedSleepHours(12.75), 0.0);
      expect(HealthScoreCalculator.adjustedSleepHours(16.0), -6.5);
    });

    test('the function is continuous at both knees', () {
      expect(
          HealthScoreCalculator.adjustedSleepHours(7.4999), closeTo(7.5, 1e-3));
      expect(
          HealthScoreCalculator.adjustedSleepHours(9.0001), closeTo(7.5, 1e-3));
    });
  });

  group('negative sub-scores are preserved, not floored', () {
    test('overtraining drives resistance to -9', () {
      final r = calc.calculate(
          const WeeklyTotals(resistanceMinutes: 200, sleepHoursPerNight: []));
      expect(r[ActivityCategory.resistance].subScore, -9.0);
      expect(r[ActivityCategory.resistance].points, -72.0);
    });

    test('a fully deprived week goes negative overall', () {
      final r = calc.calculate(const WeeklyTotals(
        sleepHoursPerNight: [0, 0, 0, 0, 0, 0, 0],
      ));
      expect(r[ActivityCategory.sleep].subScore, closeTo(-10.0, 1e-9));
      expect(r.compositePercent, lessThan(0));
      expect(r.compositePercent, closeTo(-20.118, 0.001));
    });

    test('an empty week scores exactly zero', () {
      final r = calc.calculate(const WeeklyTotals());
      expect(r.compositePercent, 0.0);
    });
  });

  group('partial weeks', () {
    const threeSeventhsOfPerfect = WeeklyTotals(
      moderateMinutes: 900 * 3 / 7,
      vigorousMinutes: 215 * 3 / 7,
      resistanceMinutes: 50 * 3 / 7,
      flexibilityMinutes: 45 * 3 / 7,
      natureMinutes: 120 * 3 / 7,
      socializingHours: 21 * 3 / 7,
      sleepHoursPerNight: [8, 8, 8],
    );

    test('pace basis reads an on-track partial week as 100%', () {
      final r = calc.calculate(threeSeventhsOfPerfect,
          daysElapsed: 3, basis: ScoreBasis.pace);
      expect(r.compositePercent, closeTo(100.0, 1e-9));
    });

    test('fullWeek basis reads the same data as raw progress', () {
      final r = calc.calculate(threeSeventhsOfPerfect, daysElapsed: 3);
      expect(
          r[ActivityCategory.flexibility].subScore, closeTo(10 * 3 / 7, 1e-9));
      expect(r.compositePercent, lessThan(60));
    });

    test('daysElapsed is ignored under fullWeek basis', () {
      expect(calc.calculate(baseline, daysElapsed: 2).compositePercent,
          closeTo(calc.calculate(baseline).compositePercent, 1e-12));
    });

    test('daysElapsed is clamped to 1..7', () {
      expect(calc.calculate(baseline, daysElapsed: 99).daysElapsed, 7);
      expect(calc.calculate(baseline, daysElapsed: 0).daysElapsed, 1);
    });
  });
}
