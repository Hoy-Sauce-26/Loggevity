import 'package:drift/drift.dart';

import '../scoring/scoring.dart';
import 'connection.dart';

part 'database.g.dart';

/// A single logged activity.
///
/// [occurredAt] is the UTC instant, used for ordering and audit. [localDate]
/// is the `YYYY-MM-DD` local-time key that decides which day - and so which
/// week - the entry counts toward. Storing both is what keeps day bucketing
/// stable across timezone travel and DST.
@TableIndex(name: 'idx_daily_entries_local_date', columns: {#localDate})
@TableIndex(name: 'idx_daily_entries_category', columns: {#category})
class DailyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get localDate => text().withLength(min: 10, max: 10)();

  /// Stored as the enum's ordinal. See `enum_ordinals_test.dart` - reordering
  /// [ActivityCategory] would silently recategorise every existing row.
  IntColumn get category => intEnum<ActivityCategory>()();

  /// Minutes for the four activity categories and nature; hours for
  /// socializing and sleep. See [ActivityCategory.unit].
  RealColumn get value => real()();

  TextColumn get note => text().nullable()();
}

/// A completed week, frozen once sealed.
class WeeklySnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Local midnight on the first day of the week. Unique, and interpreted
  /// against the week-start setting in force when the snapshot was sealed.
  DateTimeColumn get weekStartDate => dateTime().unique()();

  /// Which weekday this snapshot's week began on, captured at seal time so a
  /// later change to the setting cannot retroactively reinterpret history.
  IntColumn get weekStartDay =>
      integer().withDefault(const Constant(DateTime.monday))();

  RealColumn get compositeScore => real()();
  RealColumn get scoreModPA => real()();
  RealColumn get scoreVigPA => real()();
  RealColumn get scoreRes => real()();
  RealColumn get scoreFlex => real()();
  RealColumn get scoreNat => real()();
  RealColumn get scoreSoc => real()();
  RealColumn get scoreSleep => real()();
  BoolColumn get isSealed => boolean().withDefault(const Constant(false))();
}

/// Single-row settings table. Kept in the database rather than in
/// shared_preferences so changes push through the same reactive pipeline as
/// the entries themselves.
class AppSettings extends Table {
  /// Always 0 - this table holds exactly one row.
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// 1 = Monday .. 7 = Sunday. User-configurable.
  IntColumn get weekStartDay =>
      integer().withDefault(const Constant(DateTime.monday))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DailyEntries, WeeklySnapshots, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// For tests and tooling: an in-memory or otherwise supplied executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // No migrations yet - schemaVersion is still 1. New versions append
          // a step here and a golden schema under test/data/schemas/.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Guarantee the singleton settings row exists, on fresh installs and
          // on databases created before this table did.
          await into(appSettings).insertOnConflictUpdate(
            const AppSettingsCompanion(id: Value(0)),
          );
        },
      );

  /// The one settings row, created on first open.
  Stream<AppSetting> watchSettings() =>
      (select(appSettings)..where((t) => t.id.equals(0))).watchSingle();

  Future<AppSetting> loadSettings() =>
      (select(appSettings)..where((t) => t.id.equals(0))).getSingle();

  Future<void> setWeekStartDay(int weekday) {
    assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
    return (update(appSettings)..where((t) => t.id.equals(0)))
        .write(AppSettingsCompanion(weekStartDay: Value(weekday)));
  }
}
