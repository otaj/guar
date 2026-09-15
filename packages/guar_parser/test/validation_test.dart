// Construction-time validation for parser domain primitives.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BeanDate', () {
    test('rejects impossible calendar dates', () {
      expect(() => BeanDate(year: 2022, month: 13, day: 35), throwsArgumentError);
      expect(() => BeanDate(year: 2021, month: 2, day: 29), throwsArgumentError);
    });
  });

  group('Currency and Account', () {
    test('reject invalid names', () {
      expect(() => Currency(name: ''), throwsArgumentError);
      expect(() => Account(name: 'Assets'), throwsArgumentError);
      expect(() => Account(name: 'assets:Cash'), throwsArgumentError);
    });
  });

  group('BeanLocation.shifted', () {
    test('keeps a valid span after shifting', () {
      final shifted = BeanLocation(linenoBegin: 2, linenoEnd: 4).shifted(3);
      expect(shifted.linenoBegin, 5);
      expect(shifted.linenoEnd, 7);
    });
  });
}
