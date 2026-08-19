import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/week.dart';
import 'package:loggevity/scoring/scoring.dart';

/// The seven rows of the source workbook's `Tracker` sheet, as a user would
/// actually enter them: one log at a time, day by day.
const trackerWeek = <int, Map<ActivityCategory, double>>{
  6: {
    ActivityCategory.moderatePA: 50,
    ActivityCategory.resistance: 25,
    ActivityCategory.nature: 5,
    ActivityCategory.socializing: 4,
    ActivityCategory.sleep: 9.0,
  },
  7: {
    ActivityCategory.moderatePA: 75,
    ActivityCategory.nature: 41,
    ActivityCategory.socializing: 2,
    ActivityCategory.sleep: 9.0,
  },
  8: {
    ActivityCategory.moderatePA: 110,
    ActivityCategory.socializing: 3,
    ActivityCategory.sleep: 8.5,
  },
  9: {
    ActivityCategory.moderatePA: 85,
    ActivityCategory.resistance: 15,
    ActivityCategory.socializing: 4,
    ActivityCategory.sleep: 8.75,
  },
  10: {
    ActivityCategory.moderatePA: 54,
    ActivityCategory.resistance: 5,
    ActivityCategory.flexibility: 24,
    ActivityCategory.nature: 30,
    ActivityCategory.sleep: 8.0,
  },
  11: {
    ActivityCategory.moderatePA: 115,
    ActivityCategory.nature: 60,
    ActivityCategory.socializing: 6,
    ActivityCategory.sleep: 7.75,
  },
  12: {
    ActivityCategory.moderatePA: 35,
    ActivityCategory.resistance: 5,
    ActivityCategory.flexibility: 26,
    ActivityCategory.socializing: 3,
    ActivityCategory.sleep: 7.25,
  },
};

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  // Sunday evening of Baseline Week 1, so the week reads as fully elapsed.
  var now = DateTime(2026, 7, 12, 22);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> seedTrackerWeek() async {
    for (final entry in trackerWeek.entries) {
      for (final log in entry.value.entries) {
        await repo.log(
          category: log.key,
          value: log.value,
          occurredAt: DateTime(2026, 7, entry.key, 12),
        );
      }
    }
  }

  group('Baseline Week 1, entered one log at a time', () {
    test('aggregates back to the workbook totals', () async {
      await seedTrackerWeek();
      final m = await repo.loadWeek(WeekRange.containing(DateTime(2026, 7, 9)));
      expect(m.totals.moderateMinutes, 524);
      expect(m.totals.vigorousMinutes, 0);
      expect(m.totals.resistanceMinutes, 50);
      expect(m.totals.flexibilityMinutes, 50);
      expect(m.totals.natureMinutes, 136);
      expect(m.totals.socializingHours, 22);
      expect(
          m.totals.sleepHoursPerNight, [9.0, 9.0, 8.5, 8.75, 8.0, 7.75, 7.25]);
    });

    test('scores 84.77% end to end', () async {
      await seedTrackerWeek();
      final m = await repo.loadWeek(WeekRange.containing(DateTime(2026, 7, 9)));
      expect(m.daysElapsed, 7);
      expect(m.full.compositePercent, closeTo(84.77, 0.005));
      expect(m.full.adjustedSleepHours, closeTo(52.0, 1e-9));
      // A fully elapsed week scores the same on either basis.
      expect(m.pace.compositePercent, closeTo(84.77, 0.005));
    });

    test('entries outside the week are excluded', () async {
      await seedTrackerWeek();
      await repo.log(
        category: ActivityCategory.moderatePA,
        value: 999,
        occurredAt: DateTime(2026, 7, 13, 9), // the next Monday
      );
      await repo.log(
        category: ActivityCategory.moderatePA,
        value: 999,
        occurredAt: DateTime(2026, 7, 5, 9), // the previous Sunday
      );
      final m = await repo.loadWeek(WeekRange.containing(DateTime(2026, 7, 9)));
      expect(m.totals.moderateMinutes, 524);
    });
  });

  group('sleep bucketing', () {
    test('multiple same-day entries sum into one night', () async {
      final day = DateTime(2026, 7, 6, 8);
      await repo.log(
          category: ActivityCategory.sleep, value: 6.5, occurredAt: day);
      await repo.log(
          category: ActivityCategory.sleep,
          value: 1.5, // an afternoon nap
          occurredAt: DateTime(2026, 7, 6, 15));
      final m = await repo.loadWeek(WeekRange.containing(day));
      expect(m.totals.sleepHoursPerNight, [8.0]);
      // 8.0h sits in the flat band, so the night is worth a full 7.5 adjusted.
      expect(m.full.adjustedSleepHours, 7.5);
    });

    test('nights are ordered by date, not insertion order', () async {
      await repo.log(
          category: ActivityCategory.sleep,
          value: 7.0,
          occurredAt: DateTime(2026, 7, 10, 8));
      await repo.log(
          category: ActivityCategory.sleep,
          value: 9.0,
          occurredAt: DateTime(2026, 7, 6, 8));
      final m = await repo.loadWeek(WeekRange.containing(DateTime(2026, 7, 6)));
      expect(m.totals.sleepHoursPerNight, [9.0, 7.0]);
    });
  });

  group('reactivity', () {
    test('a new log pushes a rescored week to listeners', () async {
      final week = WeekRange.containing(DateTime(2026, 7, 9));
      final scores = <double>[];
      final sub = repo
          .watchWeek(week)
          .listen((m) => scores.add(m.full.compositePercent));
      await pumpEventQueue();
      expect(scores.single, 0.0);

      await repo.log(
          category: ActivityCategory.socializing,
          value: 21,
          occurredAt: DateTime(2026, 7, 8, 18));
      await pumpEventQueue();
      await sub.cancel();

      expect(scores, hasLength(2));
      // Socializing alone is worth 500/1690 of the composite.
      expect(scores.last, closeTo(500 / 1690 * 100, 1e-9));
    });

    test('editing and deleting also re-emit', () async {
      final week = WeekRange.containing(DateTime(2026, 7, 9));
      final id = await repo.log(
          category: ActivityCategory.nature,
          value: 60,
          occurredAt: DateTime(2026, 7, 8, 10));

      final emissions = <double>[];
      final sub = repo
          .watchWeek(week)
          .listen((m) => emissions.add(m.totals.natureMinutes));
      await pumpEventQueue();

      await repo.updateEntry(id, value: 120);
      await pumpEventQueue();
      await repo.deleteEntry(id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [60, 120, 0]);
    });

    test('entryCount tracks the underlying rows', () async {
      final week = WeekRange.containing(DateTime(2026, 7, 9));
      await seedTrackerWeek();
      final m = await repo.loadWeek(week);
      expect(m.entryCount, 30);
      expect(m.isEmpty, isFalse);
      expect((await repo.loadWeek(week.next)).isEmpty, isTrue);
    });
  });

  group('watchCurrentWeek follows the week-start setting', () {
    test('re-buckets when the user changes their start day', () async {
      now = DateTime(2026, 7, 9, 12); // a Thursday
      final starts = <String>[];
      final sub =
          repo.watchCurrentWeek().listen((m) => starts.add(m.week.startKey));
      await pumpEventQueue();
      expect(starts, ['2026-07-06']); // default Monday start

      await db.setWeekStartDay(DateTime.sunday);
      await pumpEventQueue();
      await sub.cancel();

      expect(starts, ['2026-07-06', '2026-07-05']);
    });

    test('a mid-week log is scored on pace, not raw progress', () async {
      now = DateTime(2026, 7, 8, 20); // Wednesday, 3 days elapsed
      // Three days of perfectly on-pace socializing: 3/7 of the weekly target.
      for (var d = 6; d <= 8; d++) {
        await repo.log(
          category: ActivityCategory.socializing,
          value: 3.0, // 21h/week ÷ 7
          occurredAt: DateTime(2026, 7, d, 19),
        );
      }
      final m = await repo.watchCurrentWeek().first;
      expect(m.daysElapsed, 3);
      // On pace: the category reads as fully on track.
      expect(m.pace[ActivityCategory.socializing].subScore, closeTo(10, 1e-9));
      // Raw: only 9 of 21 hours are actually banked.
      expect(m.full[ActivityCategory.socializing].subScore,
          closeTo(9 / 21 * 10, 1e-9));
    });
  });
}
