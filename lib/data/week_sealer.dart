import 'package:drift/drift.dart';

import '../scoring/scoring.dart';
import 'database.dart';
import 'metrics_repository.dart';
import 'week.dart';

/// Freezes completed weeks into [WeeklySnapshots].
///
/// Runs on launch rather than on a timer: the app has no background execution,
/// so the only reliable moment to notice a week boundary has passed is when
/// the user next opens it. That may be minutes or months later, so this walks
/// every completed week since the first entry rather than assuming exactly one
/// week has elapsed.
class WeekSealer {
  const WeekSealer(this.db, this.repo);

  final AppDatabase db;
  final MetricsRepository repo;

  /// Seals every completed week that has entries. Returns how many it wrote.
  ///
  /// Idempotent, and deliberately recomputes rather than skipping weeks that
  /// already have a snapshot: a snapshot is derived data, so editing a past
  /// entry should correct the history rather than leave it stale.
  Future<int> sealCompletedWeeks() async {
    final settings = await db.loadSettings();
    final startDay = settings.weekStartDay;
    final currentWeek =
        WeekRange.containing(repo.now(), weekStartDay: startDay);

    final earliest = await repo.earliestEntryDate();
    if (earliest == null) return 0;

    var week = WeekRange.containing(earliest, weekStartDay: startDay);
    var sealed = 0;
    while (week.start.isBefore(currentWeek.start)) {
      final metrics = await repo.loadWeek(week);
      // An empty week is a gap in logging, not a zero-scoring week, so it is
      // left out of the history entirely.
      if (!metrics.isEmpty) {
        await db.upsertSnapshot(_toCompanion(week, metrics));
        sealed++;
      }
      week = week.next;
    }
    return sealed;
  }

  WeeklySnapshotsCompanion _toCompanion(WeekRange week, WeeklyMetrics m) {
    double sub(ActivityCategory c) => m.full[c].subScore;
    return WeeklySnapshotsCompanion.insert(
      weekStartDate: week.start,
      weekStartDay: Value(week.weekStartDay),
      compositeScore: m.full.compositePercent,
      scoreModPA: sub(ActivityCategory.moderatePA),
      scoreVigPA: sub(ActivityCategory.vigorousPA),
      scoreRes: sub(ActivityCategory.resistance),
      scoreFlex: sub(ActivityCategory.flexibility),
      scoreNat: sub(ActivityCategory.nature),
      scoreSoc: sub(ActivityCategory.socializing),
      scoreSleep: sub(ActivityCategory.sleep),
      isSealed: const Value(true),
    );
  }
}

/// Convenience accessors for a stored snapshot.
extension WeeklySnapshotScores on WeeklySnapshot {
  double subScoreFor(ActivityCategory category) => switch (category) {
        ActivityCategory.moderatePA => scoreModPA,
        ActivityCategory.vigorousPA => scoreVigPA,
        ActivityCategory.resistance => scoreRes,
        ActivityCategory.flexibility => scoreFlex,
        ActivityCategory.nature => scoreNat,
        ActivityCategory.socializing => scoreSoc,
        ActivityCategory.sleep => scoreSleep,
      };

  /// Weighted points this category contributed to the composite.
  double pointsFor(ActivityCategory category) =>
      subScoreFor(category) * category.weight;
}
