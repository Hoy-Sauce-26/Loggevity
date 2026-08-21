import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/week.dart';

void main() {
  group('localDateKey', () {
    test('zero-pads to a sortable YYYY-MM-DD', () {
      expect(localDateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(localDateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('sorts lexicographically in chronological order', () {
      final keys = [
        localDateKey(DateTime(2026, 12, 31)),
        localDateKey(DateTime(2026, 1, 5)),
        localDateKey(DateTime(2027, 1, 1)),
      ]..sort();
      expect(keys, ['2026-01-05', '2026-12-31', '2027-01-01']);
    });
  });

  group('WeekRange with a Monday start', () {
    // The canonical reference week: Mon 2026-07-06 .. Sun 2026-07-12.
    final week = WeekRange.containing(DateTime(2026, 7, 9));

    test('snaps back to Monday', () {
      expect(week.startKey, '2026-07-06');
      expect(localDateKey(week.lastDay), '2026-07-12');
      expect(week.endExclusiveKey, '2026-07-13');
    });

    test('every day of the week maps to the same range', () {
      for (var d = 6; d <= 12; d++) {
        expect(WeekRange.containing(DateTime(2026, 7, d)), week);
      }
      expect(WeekRange.containing(DateTime(2026, 7, 13)), isNot(week));
      expect(WeekRange.containing(DateTime(2026, 7, 5)), isNot(week));
    });

    test('lists seven consecutive days', () {
      expect(week.days.length, 7);
      expect(week.days.map(localDateKey).toList(), [
        '2026-07-06',
        '2026-07-07',
        '2026-07-08',
        '2026-07-09',
        '2026-07-10',
        '2026-07-11',
        '2026-07-12',
      ]);
    });

    test('contains its own days and excludes the boundaries', () {
      expect(week.contains(DateTime(2026, 7, 6)), isTrue);
      expect(week.contains(DateTime(2026, 7, 12, 23, 59)), isTrue);
      expect(week.contains(DateTime(2026, 7, 13)), isFalse);
      expect(week.contains(DateTime(2026, 7, 5, 23, 59)), isFalse);
    });

    test('steps to adjacent weeks', () {
      expect(week.next.startKey, '2026-07-13');
      expect(week.previous.startKey, '2026-06-29');
      expect(week.next.previous, week);
    });
  });

  group('configurable week start', () {
    test('the same instant lands in different weeks per setting', () {
      final thursday = DateTime(2026, 7, 9);
      expect(
        WeekRange.containing(thursday, weekStartDay: DateTime.monday).startKey,
        '2026-07-06',
      );
      expect(
        WeekRange.containing(thursday, weekStartDay: DateTime.sunday).startKey,
        '2026-07-05',
      );
      expect(
        WeekRange.containing(thursday, weekStartDay: DateTime.saturday)
            .startKey,
        '2026-07-04',
      );
      expect(
        WeekRange.containing(thursday, weekStartDay: DateTime.thursday)
            .startKey,
        '2026-07-09',
      );
    });

    test('a week starting on its own weekday begins that day', () {
      for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
        final w = WeekRange.containing(DateTime(2026, 7, 9), weekStartDay: d);
        expect(w.start.weekday, d);
        expect(w.contains(DateTime(2026, 7, 9)), isTrue);
      }
    });

    test('ranges with different start days are not equal', () {
      expect(
        WeekRange.containing(DateTime(2026, 7, 9),
            weekStartDay: DateTime.monday),
        isNot(WeekRange.containing(DateTime(2026, 7, 9),
            weekStartDay: DateTime.sunday)),
      );
    });
  });

  group('daysElapsedAt', () {
    final week = WeekRange.containing(DateTime(2026, 7, 6));

    test('counts from 1 on the first day to 7 on the last', () {
      expect(week.daysElapsedAt(DateTime(2026, 7, 6, 0, 1)), 1);
      expect(week.daysElapsedAt(DateTime(2026, 7, 8, 12)), 3);
      expect(week.daysElapsedAt(DateTime(2026, 7, 12, 23, 59)), 7);
    });

    test('a finished week is always 7', () {
      expect(week.daysElapsedAt(DateTime(2026, 7, 13)), 7);
      expect(week.daysElapsedAt(DateTime(2027, 1, 1)), 7);
    });

    test('a future week clamps to 1', () {
      expect(week.daysElapsedAt(DateTime(2026, 1, 1)), 1);
    });
  });

  group('DST and month boundaries', () {
    test('a week spanning a month end still covers seven days', () {
      final w = WeekRange.containing(DateTime(2026, 3, 31));
      expect(w.days.length, 7);
      expect(w.days.first.hour, 0);
      expect(w.days.every((d) => d.hour == 0), isTrue);
      expect(w.endExclusive.difference(w.start).inDays, inInclusiveRange(6, 8));
    });

    test('every day stays at local midnight across a US DST transition', () {
      // 2026-03-08 is the US spring-forward date.
      final w = WeekRange.containing(DateTime(2026, 3, 8));
      expect(w.days.every((d) => d.hour == 0 && d.minute == 0), isTrue);
      expect(w.start.hour, 0);
      expect(w.endExclusive.hour, 0);
    });

    test('spans a year boundary', () {
      final w = WeekRange.containing(DateTime(2026, 12, 31));
      expect(w.contains(DateTime(2026, 12, 31)), isTrue);
      expect(w.days.length, 7);
    });
  });
}
