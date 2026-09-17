// Construction-time validation for parser domain primitives.

import 'dart:io';

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BeanDate', () {
    test('accepts a real calendar day', () {
      expect(BeanDate(year: 2020, month: 2, day: 29).toString(), '2020-02-29');
    });

    test('rejects impossible calendar dates', () {
      expect(() => BeanDate(year: 2022, month: 13, day: 35), throwsArgumentError);
      expect(() => BeanDate(year: 2021, month: 2, day: 29), throwsArgumentError);
      expect(() => BeanDate(year: 2022, month: 4, day: 31), throwsArgumentError);
      expect(() => BeanDate(year: 0, month: 1, day: 1), throwsArgumentError);
    });
  });

  group('Currency', () {
    test('accepts Beancount currency codes', () {
      expect(Currency(name: 'USD').name, 'USD');
      expect(Currency(name: '/NQH21').name, '/NQH21');
    });

    test('rejects empty or malformed codes', () {
      expect(() => Currency(name: ''), throwsArgumentError);
      expect(() => Currency(name: 'usd'), throwsArgumentError);
      expect(() => Currency(name: '/'), throwsArgumentError);
    });
  });

  group('Account', () {
    test('accepts a multi-component account', () {
      expect(Account(name: 'Assets:Cash').name, 'Assets:Cash');
    });

    test('rejects root-only, lowercase, or empty components', () {
      expect(() => Account(name: 'Assets'), throwsArgumentError);
      expect(() => Account(name: 'assets:Cash'), throwsArgumentError);
      expect(() => Account(name: 'Assets:'), throwsArgumentError);
      expect(() => Account(name: ':Cash'), throwsArgumentError);
    });
  });

  group('Tag and Link', () {
    test('reject empty or whitespace names', () {
      expect(() => Tag(name: ''), throwsArgumentError);
      expect(() => Tag(name: 'a b'), throwsArgumentError);
      expect(() => Link(name: ''), throwsArgumentError);
    });
  });

  group('Flag.letter', () {
    test('accepts a single uppercase letter', () {
      expect(Flag.letter('P'), isA<LetterFlag>());
    });

    test('rejects other shapes', () {
      expect(() => Flag.letter('p'), throwsArgumentError);
      expect(() => Flag.letter('PP'), throwsArgumentError);
      expect(() => Flag.letter('!'), throwsArgumentError);
    });
  });

  group('BeanLocation', () {
    test('rejects negative or inverted line ranges', () {
      expect(() => BeanLocation(linenoBegin: -1, linenoEnd: 1), throwsArgumentError);
      expect(() => BeanLocation(linenoBegin: 5, linenoEnd: 4), throwsArgumentError);
    });

    test('shifted keeps a valid span', () {
      final shifted = BeanLocation(linenoBegin: 2, linenoEnd: 4).shifted(3);
      expect(shifted.linenoBegin, 5);
      expect(shifted.linenoEnd, 7);
    });
  });

  test('parser and domain validation.dart stay in lockstep', () {
    String withoutHeader(String path) {
      final lines = File(path).readAsLinesSync();
      return lines.skip(1).join('\n');
    }

    expect(withoutHeader('lib/src/domain/validation.dart'), withoutHeader('../guar_domain/lib/src/validation.dart'));
  });
}
