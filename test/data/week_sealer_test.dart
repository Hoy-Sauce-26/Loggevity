import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/week_sealer.dart';
import 'package:loggevity/scoring/scoring.dart';

import 'metrics_repository_test.dart' show trackerWeek;

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  late WeekSealer sealer;
  var now = DateTime(2026, 7, 15, 9); // the Wednesday after Baseline Week 1

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
    sealer = WeekSealer(db, repo);
  });
  tearDown(() => db.close());

  Future<void> seedTrackerWeek() async {
    for (final day in trackerWeek.entries) {
      for (final log in day.value.entries) {
        await repo.log(
          category: log.key,
          value: log.value,
          occurredAt: DateTime(2026, 7, day.key, 12),
        );
      }
    }
  }

  group('sealing a completed week', () {
    test('writes the composite and all seven sub-scores', () async {
      await seedTrackerWeek();
      expect(await sealer.sealCompletedWeeks(), 1);

      final snapshot = await db.select(db.weeklySnapshots).getSingle();
      expect(snapshot.weekStartDate, DateTime(2026, 7, 6));
      expect(snapshot.isSealed, isTrue);
      expect(snapshot.compositeScore, closeTo(84.77, 0.005));
      expect(snapshot.scoreModPA, closeTo(7.396923077, 1e-9));
      expect(snapshot.scoreVigPA, 0);
      expect(snapshot.scoreRes, 10);
      expect(snapshot.scoreFlex, 10);
      expect(snapshot.scoreNat, 10);
      expect(snapshot.scoreSoc, 10);
      expect(snapshot.scoreSleep, closeTo(9.904761905, 1e-9));
    });

    test('records the week-start day in force at seal time', () async {
      await db.setWeekStartDay(DateTime.sunday);
      await seedTrackerWeek();
      await sealer.sealCompletedWeeks();

      final snapshots = await db.select(db.weeklySnapshots).get();
      expect(snapshots.every((s) => s.weekStartDay == DateTime.sunday), isTrue);
      // A Sunday-start week begins the day before the Monday-start one.
      expect(snapshots.first.weekStartDate, DateTime(2026, 7, 5));
    });

    test('exposes sub-scores and weighted points by category', () async {
      await seedTrackerWeek();
      await sealer.sealCompletedWeeks();
      final s = await db.select(db.weeklySnapshots).getSingle();

      expect(s.subScoreFor(ActivityCategory.socializing), 10);
      expect(s.pointsFor(ActivityCategory.socializing), 500);
      expect(s.pointsFor(ActivityCategory.vigorousPA), 0);
    });
  });

  group('boundary behaviour', () {
    test('never seals the week in progress', () async {
      now = DateTime(2026, 7, 8, 20); // mid Baseline Week 1
      await seedTrackerWeek();

      expect(await sealer.sealCompletedWeeks(), 0);
      expect(await db.select(db.weeklySnapshots).get(), isEmpty);
    });

    test('seals it once the boundary is crossed', () async {
      now = DateTime(2026, 7, 8, 20);
      await seedTrackerWeek();
      expect(await sealer.sealCompletedWeeks(), 0);

      now = DateTime(2026, 7, 13, 0, 1); // the following Monday
      expect(await sealer.sealCompletedWeeks(), 1);
    });

    test('catches up on many weeks after a long absence', () async {
      // Log one thing a week for eight weeks, then open the app months later.
      for (var w = 0; w < 8; w++) {
        await repo.log(
          category: ActivityCategory.nature,
          value: 60,
          occurredAt: DateTime(2026, 7, 6 + w * 7, 12),
        );
      }
      now = DateTime(2026, 11, 4);

      expect(await sealer.sealCompletedWeeks(), 8);
      final snapshots = await db.select(db.weeklySnapshots).get();
      expect(snapshots, hasLength(8));
      expect(snapshots.first.weekStartDate, DateTime(2026, 7, 6));
      expect(snapshots.last.weekStartDate, DateTime(2026, 8, 24));
    });

    test('skips weeks with no entries rather than recording a zero', () async {
      await repo.log(
        category: ActivityCategory.nature,
        value: 60,
        occurredAt: DateTime(2026, 7, 6, 12),
      );
      // Nothing at all in the intervening three weeks.
      await repo.log(
        category: ActivityCategory.nature,
        value: 60,
        occurredAt: DateTime(2026, 8, 3, 12),
      );
      now = DateTime(2026, 8, 12);

      expect(await sealer.sealCompletedWeeks(), 2);
      final starts = (await db.select(db.weeklySnapshots).get())
          .map((s) => s.weekStartDate)
          .toList();
      expect(starts, [DateTime(2026, 7, 6), DateTime(2026, 8, 3)]);
    });

    test('does nothing when nothing has ever been logged', () async {
      expect(await sealer.sealCompletedWeeks(), 0);
      expect(await db.select(db.weeklySnapshots).get(), isEmpty);
    });
  });

  group('idempotency', () {
    test('re-running does not duplicate rows', () async {
      await seedTrackerWeek();
      await sealer.sealCompletedWeeks();
      await sealer.sealCompletedWeeks();
      await sealer.sealCompletedWeeks();

      expect(await db.select(db.weeklySnapshots).get(), hasLength(1));
    });

    test('editing a past week corrects its snapshot on the next seal',
        () async {
      await seedTrackerWeek();
      await sealer.sealCompletedWeeks();
      final before = await db.select(db.weeklySnapshots).getSingle();
      expect(before.scoreVigPA, 0);

      // Retroactively log the vigorous session that was missed.
      await repo.log(
        category: ActivityCategory.vigorousPA,
        value: 200,
        occurredAt: DateTime(2026, 7, 9, 7),
      );
      await sealer.sealCompletedWeeks();

      final after = await db.select(db.weeklySnapshots).getSingle();
      expect(after.scoreVigPA, closeTo(9.826086957, 1e-9));
      expect(after.compositeScore, closeTo(93.49, 0.005));
      expect(await db.select(db.weeklySnapshots).get(), hasLength(1));
    });
  });
}
