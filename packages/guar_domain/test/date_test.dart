// Ordering and civil-calendar arithmetic for BeanDate.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

BeanDate d(int year, int month, int day) => BeanDate(year: year, month: month, day: day);

void main() {
  group('compareBeanDate', () {
    test('orders by year then month then day', () {
      expect(compareBeanDate(d(2020, 1, 1), d(2021, 1, 1)), isNegative);
      expect(compareBeanDate(d(2021, 1, 1), d(2020, 1, 1)), isPositive);
      expect(compareBeanDate(d(2020, 1, 1), d(2020, 2, 1)), isNegative);
      expect(compareBeanDate(d(2020, 2, 1), d(2020, 1, 1)), isPositive);
      expect(compareBeanDate(d(2020, 1, 1), d(2020, 1, 2)), isNegative);
      expect(compareBeanDate(d(2020, 1, 2), d(2020, 1, 1)), isPositive);
      expect(compareBeanDate(d(2020, 6, 15), d(2020, 6, 15)), 0);
    });
  });

  group('addDays', () {
    test('rolls across month and year boundaries', () {
      expect(addDays(d(2020, 1, 31), 1), d(2020, 2, 1));
      expect(addDays(d(2020, 12, 31), 1), d(2021, 1, 1));
      expect(addDays(d(2021, 1, 1), -1), d(2020, 12, 31));
    });

    test('accepts a leap day and rolls off February', () {
      expect(addDays(d(2020, 2, 28), 1), d(2020, 2, 29));
      expect(addDays(d(2020, 2, 29), 1), d(2020, 3, 1));
      expect(addDays(d(2021, 2, 28), 1), d(2021, 3, 1));
    });
  });

  group('addDelta', () {
    test('clamps month-end to the last valid day', () {
      expect(addDelta(d(2021, 1, 31), const DateDelta(months: 1)), d(2021, 2, 28));
      expect(addDelta(d(2020, 1, 31), const DateDelta(months: 1)), d(2020, 2, 29));
      expect(addDelta(d(2021, 3, 31), const DateDelta(months: 1)), d(2021, 4, 30));
    });

    test('applies years months and days in that order', () {
      expect(addDelta(d(2020, 1, 15), const DateDelta(years: 1, months: 1, days: 1)), d(2021, 2, 16));
      expect(addDelta(d(2021, 3, 1), const DateDelta(months: -1)), d(2021, 2, 1));
    });
  });
}
