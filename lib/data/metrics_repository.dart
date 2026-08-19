import 'package:drift/drift.dart';

import '../scoring/scoring.dart';
import 'database.dart';
import 'week.dart';

/// Everything the UI needs to render one week, recomputed from scratch on
/// every underlying change.
class WeeklyMetrics {
  const WeeklyMetrics({
    required this.week,
    required this.totals,
    required this.daysElapsed,
    required this.pace,
    required this.full,
    required this.entryCount,
  });

  final WeekRange week;
  final WeeklyTotals totals;

  /// 1..7. Drives the prorated [pace] score.
  final int daysElapsed;

  /// Targets scaled to [daysElapsed]. Drives the headline ring.
  final ScoreResult pace;

  /// Raw progress toward the full-week targets. Drives the category bars.
  final ScoreResult full;

  final int entryCount;

  bool get isEmpty => entryCount == 0;
}

/// Reactive bridge between the database and the scoring engine.
///
/// Every stream here is driven by drift's table-update notifications, so adding,
/// editing or deleting a log pushes a freshly scored [WeeklyMetrics] to every
/// listener without any manual invalidation.
class MetricsRepository {
  MetricsRepository(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// The repository's notion of "now". Injectable so tests can pin the week.
  DateTime now() => _clock();

  static const _calculator = HealthScoreCalculator();

  /// Folds raw rows into the scoring engine's input shape.
  ///
  /// Sleep is bucketed by local date and summed within a day, so a nap logged
  /// alongside a night's sleep counts toward that day's total rather than
  /// registering as a separate short night.
  static WeeklyTotals aggregate(Iterable<DailyEntry> entries) {
    var moderate = 0.0, vigorous = 0.0, resistance = 0.0;
    var flexibility = 0.0, nature = 0.0, social = 0.0;
    final sleepByDay = <String, double>{};

    for (final e in entries) {
      switch (e.category) {
        case ActivityCategory.moderatePA:
          moderate += e.value;
        case ActivityCategory.vigorousPA:
          vigorous += e.value;
        case ActivityCategory.resistance:
          resistance += e.value;
        case ActivityCategory.flexibility:
          flexibility += e.value;
        case ActivityCategory.nature:
          nature += e.value;
        case ActivityCategory.socializing:
          social += e.value;
        case ActivityCategory.sleep:
          sleepByDay.update(e.localDate, (v) => v + e.value,
              ifAbsent: () => e.value);
      }
    }

    final nights = sleepByDay.keys.toList()..sort();
    return WeeklyTotals(
      moderateMinutes: moderate,
      vigorousMinutes: vigorous,
      resistanceMinutes: resistance,
      flexibilityMinutes: flexibility,
      natureMinutes: nature,
      socializingHours: social,
      sleepHoursPerNight: [for (final d in nights) sleepByDay[d]!],
    );
  }

  WeeklyMetrics _score(WeekRange week, List<DailyEntry> entries) {
    final totals = aggregate(entries);
    final days = week.daysElapsedAt(_clock());
    return WeeklyMetrics(
      week: week,
      totals: totals,
      daysElapsed: days,
      pace: _calculator.calculate(totals,
          daysElapsed: days, basis: ScoreBasis.pace),
      full: _calculator.calculate(totals),
      entryCount: entries.length,
    );
  }

  SimpleSelectStatement<$DailyEntriesTable, DailyEntry> _entriesIn(
      WeekRange week) {
    return db.select(db.dailyEntries)
      ..where((t) =>
          t.localDate.isBiggerOrEqualValue(week.startKey) &
          t.localDate.isSmallerThanValue(week.endExclusiveKey))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
  }

  /// Scores one specific week, re-emitting whenever its entries change.
  Stream<WeeklyMetrics> watchWeek(WeekRange week) =>
      _entriesIn(week).watch().map((rows) => _score(week, rows));

  Future<WeeklyMetrics> loadWeek(WeekRange week) async =>
      _score(week, await _entriesIn(week).get());

  /// The user's current week, using their configured start day.
  Future<WeekRange> currentWeek() async {
    final s = await db.loadSettings();
    return WeekRange.containing(_clock(), weekStartDay: s.weekStartDay);
  }

  Stream<List<DailyEntry>> watchEntriesForWeek(WeekRange week) =>
      _entriesIn(week).watch();

  // --- mutations ---

  Future<int> log({
    required ActivityCategory category,
    required double value,
    DateTime? occurredAt,
    String? note,
  }) {
    final at = occurredAt ?? _clock();
    final local = at.isUtc ? at.toLocal() : at;
    return db.into(db.dailyEntries).insert(DailyEntriesCompanion.insert(
          occurredAt: local.toUtc(),
          localDate: localDateKey(local),
          category: category,
          value: value,
          note: Value(note),
        ));
  }

  Future<void> updateEntry(int id, {double? value, String? note}) {
    return (db.update(db.dailyEntries)..where((t) => t.id.equals(id))).write(
      DailyEntriesCompanion(
        value: value == null ? const Value.absent() : Value(value),
        note: note == null ? const Value.absent() : Value(note),
      ),
    );
  }

  Future<int> deleteEntry(int id) =>
      (db.delete(db.dailyEntries)..where((t) => t.id.equals(id))).go();
}
