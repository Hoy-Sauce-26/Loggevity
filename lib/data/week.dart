/// Week bucketing. Pure date arithmetic, no Flutter and no storage.
///
/// Everything here works in **local** time. Entries are stored with a UTC
/// instant for ordering plus a local `YYYY-MM-DD` key for bucketing; the key is
/// what decides which day - and therefore which week - an entry belongs to, so
/// a log made at 11pm stays on the day the user experienced it regardless of
/// timezone or DST changes.
library;

/// Formats a local date as the `YYYY-MM-DD` key used for day bucketing.
String localDateKey(DateTime local) {
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$m-$d';
}

/// A half-open range of seven local days, `[start, endExclusive)`.
class WeekRange {
  WeekRange._(this.start, this.weekStartDay);

  /// The week containing [instant], for a week that begins on [weekStartDay].
  ///
  /// [weekStartDay] uses `DateTime.monday`..`DateTime.sunday` (1..7). It is
  /// user-configurable, so nothing here may assume Monday.
  factory WeekRange.containing(
    DateTime instant, {
    int weekStartDay = DateTime.monday,
  }) {
    assert(weekStartDay >= DateTime.monday && weekStartDay <= DateTime.sunday);
    final local = instant.isUtc ? instant.toLocal() : instant;
    // Days since the most recent occurrence of weekStartDay.
    final delta = (local.weekday - weekStartDay + 7) % 7;
    // Built through the constructor rather than by subtracting a Duration so
    // the result stays at local midnight across DST transitions.
    return WeekRange._(
      DateTime(local.year, local.month, local.day - delta),
      weekStartDay,
    );
  }

  /// Local midnight on the first day of the week, inclusive.
  final DateTime start;

  /// Which weekday this week begins on (1 = Monday .. 7 = Sunday).
  final int weekStartDay;

  /// Local midnight on the day after the week ends, exclusive.
  DateTime get endExclusive => DateTime(start.year, start.month, start.day + 7);

  /// Local midnight on the final day of the week, inclusive.
  DateTime get lastDay => DateTime(start.year, start.month, start.day + 6);

  String get startKey => localDateKey(start);

  String get endExclusiveKey => localDateKey(endExclusive);

  /// The seven local dates in this week, in order.
  List<DateTime> get days => [
        for (var i = 0; i < 7; i++)
          DateTime(start.year, start.month, start.day + i),
      ];

  bool contains(DateTime instant) {
    final key = localDateKey(instant.isUtc ? instant.toLocal() : instant);
    return key.compareTo(startKey) >= 0 && key.compareTo(endExclusiveKey) < 0;
  }

  /// The previous week, same start day.
  WeekRange get previous => WeekRange.containing(
        DateTime(start.year, start.month, start.day - 1),
        weekStartDay: weekStartDay,
      );

  /// The next week, same start day.
  WeekRange get next =>
      WeekRange.containing(endExclusive, weekStartDay: weekStartDay);

  /// How many days of this week have begun as of [now], clamped to 1..7.
  ///
  /// A week entirely in the past returns 7; one entirely in the future
  /// returns 1. This is what drives `ScoreBasis.pace` proration.
  int daysElapsedAt(DateTime now) {
    final local = now.isUtc ? now.toLocal() : now;
    final today = DateTime(local.year, local.month, local.day);
    if (today.isBefore(start)) return 1;
    if (!today.isBefore(endExclusive)) return 7;
    return today.difference(start).inDays + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is WeekRange &&
      other.start == start &&
      other.weekStartDay == weekStartDay;

  @override
  int get hashCode => Object.hash(start, weekStartDay);

  @override
  String toString() => 'WeekRange($startKey .. ${localDateKey(lastDay)})';
}
