import 'package:drift/drift.dart';

import '../scoring/scoring.dart';
import 'database.dart';
import 'portability.dart';
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

  /// The local date of the earliest entry, or null when nothing is logged.
  /// Bounds how far back the sealing engine has to walk.
  Future<DateTime?> earliestEntryDate() async {
    final query = db.select(db.dailyEntries)
      ..orderBy([(t) => OrderingTerm.asc(t.localDate)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final parts = row.localDate.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  Future<WeeklyMetrics> loadWeek(WeekRange week) async =>
      _score(week, await _entriesIn(week).get());

  /// The user's current week, using their configured start day.
  Future<WeekRange> currentWeek() async {
    final s = await db.loadSettings();
    return WeekRange.containing(_clock(), weekStartDay: s.weekStartDay);
  }

  Stream<List<DailyEntry>> watchEntriesForWeek(WeekRange week) =>
      _entriesIn(week).watch();

  /// One category's entries for a week, oldest first.
  Stream<List<DailyEntry>> watchCategoryEntries(
    WeekRange week,
    ActivityCategory category,
  ) {
    final query = db.select(db.dailyEntries)
      ..where((t) =>
          t.localDate.isBiggerOrEqualValue(week.startKey) &
          t.localDate.isSmallerThanValue(week.endExclusiveKey) &
          t.category.equalsValue(category))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return query.watch();
  }

  /// Totals [entries] into one figure per day of [week], in day order.
  ///
  /// Every category is stored per entry with a local date, so a daily
  /// breakdown is available for all of them - not only sleep, which merely
  /// happens to be the one the scoring model consumes per day.
  static List<double> dailyTotals(
    WeekRange week,
    Iterable<DailyEntry> entries,
  ) {
    final byDay = <String, double>{};
    for (final e in entries) {
      byDay.update(e.localDate, (v) => v + e.value, ifAbsent: () => e.value);
    }
    return [for (final day in week.days) byDay[localDateKey(day)] ?? 0.0];
  }

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

  /// Edits an existing entry.
  ///
  /// [day] moves the entry to another local date - a forgotten night's sleep
  /// entered the next morning belongs to the night it happened, not to the day
  /// it was typed. [occurredAt] is rewritten to keep the same time of day on
  /// the new date, so ordering within the day survives the move.
  Future<void> updateEntry(
    int id, {
    double? value,
    String? note,
    DateTime? day,
  }) async {
    var occurredAt = const Value<DateTime>.absent();
    var localDate = const Value<String>.absent();

    if (day != null) {
      final target = day.isUtc ? day.toLocal() : day;
      final existing = await (db.select(db.dailyEntries)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (existing == null) return;
      final at = existing.occurredAt.toLocal();
      final moved = DateTime(
        target.year,
        target.month,
        target.day,
        at.hour,
        at.minute,
        at.second,
      );
      occurredAt = Value(moved.toUtc());
      localDate = Value(localDateKey(moved));
    }

    await (db.update(db.dailyEntries)..where((t) => t.id.equals(id))).write(
      DailyEntriesCompanion(
        value: value == null ? const Value.absent() : Value(value),
        note: note == null ? const Value.absent() : Value(note),
        occurredAt: occurredAt,
        localDate: localDate,
      ),
    );
  }

  Future<int> deleteEntry(int id) =>
      (db.delete(db.dailyEntries)..where((t) => t.id.equals(id))).go();

  /// Every entry, oldest first - the source for an export.
  Future<List<DailyEntry>> allEntries() {
    final query = db.select(db.dailyEntries)
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return query.get();
  }

  /// Adds imported entries, skipping any that are already present.
  ///
  /// De-duplicated on [PortableEntry.fingerprint] rather than replacing the
  /// database wholesale: an import should never be able to destroy data the
  /// user did not choose to remove, and re-importing the same file should be a
  /// no-op instead of doubling the week.
  Future<int> importEntries(List<PortableEntry> entries) async {
    if (entries.isEmpty) return 0;
    final existing = {
      for (final row in await allEntries())
        PortableEntry(
          localDate: row.localDate,
          category: row.category,
          value: row.value,
          occurredAt: row.occurredAt,
          note: row.note,
        ).fingerprint,
    };

    final fresh = <PortableEntry>[];
    for (final entry in entries) {
      if (existing.add(entry.fingerprint)) fresh.add(entry);
    }
    if (fresh.isEmpty) return 0;

    await db.batch((batch) {
      batch.insertAll(db.dailyEntries, [
        for (final e in fresh)
          DailyEntriesCompanion.insert(
            occurredAt: e.occurredAt,
            localDate: e.localDate,
            category: e.category,
            value: e.value,
            note: Value(e.note),
          ),
      ]);
    });
    return fresh.length;
  }
}
