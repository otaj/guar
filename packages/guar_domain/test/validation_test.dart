// Construction-time validation for booked domain primitives.

import 'package:guar_domain/guar_domain.dart';
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
      expect(Account(name: 'Assets:Cash', type: AccountType.assets).name, 'Assets:Cash');
    });

    test('rejects root-only, lowercase, or empty components', () {
      expect(() => Account(name: 'Assets', type: AccountType.assets), throwsArgumentError);
      expect(() => Account(name: 'assets:Cash', type: AccountType.assets), throwsArgumentError);
      expect(() => Account(name: 'Assets:', type: AccountType.assets), throwsArgumentError);
      expect(() => Account(name: ':Cash', type: AccountType.assets), throwsArgumentError);
    });

    test('budget accounts may be a single-segment root', () {
      expect(Account.budget(name: 'Expenses', type: AccountType.expenses).name, 'Expenses');
      expect(Account.budget(name: 'Expenses:Food', type: AccountType.expenses).name, 'Expenses:Food');
      expect(() => Account.budget(name: 'assets', type: AccountType.assets), throwsArgumentError);
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
  });
}
