import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'data/metrics_repository.dart';
import 'data/week.dart';

/// Overridden in tests with an in-memory executor.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final metricsRepositoryProvider = Provider<MetricsRepository>((ref) {
  return MetricsRepository(ref.watch(databaseProvider));
});

final settingsProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(databaseProvider).watchSettings();
});

/// Which weekday the user's week begins on.
final weekStartDayProvider = Provider<int>((ref) {
  // Monday until the stored setting arrives, so there is always a real week to
  // score rather than a null hole the UI has to spin on.
  return ref.watch(settingsProvider).value?.weekStartDay ?? DateTime.monday;
});

/// The week currently being logged into.
final currentWeekRangeProvider = Provider<WeekRange>((ref) {
  final repo = ref.watch(metricsRepositoryProvider);
  return WeekRange.containing(
    repo.now(),
    weekStartDay: ref.watch(weekStartDayProvider),
  );
});

/// Live week-to-date metrics. Re-emits on every log, edit or delete; rebuilds
/// outright when the user changes which day their week starts on.
///
/// The two dependencies are composed here rather than inside the repository:
/// riverpod already invalidates and disposes on change, and a hand-rolled
/// switchMap deadlocked on teardown by awaiting drift's deferred stream close.
final currentWeekProvider = StreamProvider<WeeklyMetrics>((ref) {
  final repo = ref.watch(metricsRepositoryProvider);
  return repo.watchWeek(ref.watch(currentWeekRangeProvider));
});
