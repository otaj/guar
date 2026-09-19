// Ports of beancount.core.amount_test for complete booked amounts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Amount', () {
    test('constructor keeps number and currency', () {
      final Amount amount = Amount(
        number: Decimal.parse('100034.02'),
        currency: Currency(name: 'USD'),
      );
      expect(amount.number, Decimal.parse('100034.02'));
      expect(amount.currency, Currency(name: 'USD'));
    });

    test('toString renders number then currency', () {
      expect(
        Amount(
          number: Decimal.parse('100034.023'),
          currency: Currency(name: 'USD'),
        ).toString(),
        '100034.023 USD',
      );
      expect(
        Amount(
          number: Decimal.parse('0.00000001'),
          currency: Currency(name: 'BTC'),
        ).toString(),
        '0.00000001 BTC',
      );
    });

    test('equality and hash ignore identity', () {
      final Amount a = Amount(
        number: Decimal.parse('100'),
        currency: Currency(name: 'USD'),
      );
      final Amount b = Amount(
        number: Decimal.parse('100'),
        currency: Currency(name: 'USD'),
      );
      final Amount c = Amount(
        number: Decimal.parse('101'),
        currency: Currency(name: 'USD'),
      );
      expect(a, b);
      expect(a, isNot(c));
      expect(<Amount, bool>{a: true, b: false}.length, 1);
      expect(
        <Amount, bool>{
          a: true,
          Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'CAD'),
          ): false,
        }.length,
        2,
      );
    });

    test('sort is currency-first then number', () {
      final List<Amount> amounts = <Amount>[
        Amount(
          number: Decimal.parse('1'),
          currency: Currency(name: 'USD'),
        ),
        Amount(
          number: Decimal.parse('201'),
          currency: Currency(name: 'EUR'),
        ),
        Amount(
          number: Decimal.parse('3'),
          currency: Currency(name: 'USD'),
        ),
        Amount(
          number: Decimal.parse('100'),
          currency: Currency(name: 'CAD'),
        ),
        Amount(
          number: Decimal.parse('2'),
          currency: Currency(name: 'USD'),
        ),
        Amount(
          number: Decimal.parse('200'),
          currency: Currency(name: 'EUR'),
        ),
      ]..sort(Amount.compare);
      expect(amounts, <Amount>[
        Amount(
          number: Decimal.parse('100'),
          currency: Currency(name: 'CAD'),
        ),
        Amount(
          number: Decimal.parse('200'),
          currency: Currency(name: 'EUR'),
        ),
        Amount(
          number: Decimal.parse('201'),
          currency: Currency(name: 'EUR'),
        ),
        Amount(
          number: Decimal.parse('1'),
          currency: Currency(name: 'USD'),
        ),
        Amount(
          number: Decimal.parse('2'),
          currency: Currency(name: 'USD'),
        ),
        Amount(
          number: Decimal.parse('3'),
          currency: Currency(name: 'USD'),
        ),
      ]);
    });

    test('neg flips the sign', () {
      expect(
        -Amount(
          number: Decimal.parse('100'),
          currency: Currency(name: 'CAD'),
        ),
        Amount(
          number: Decimal.parse('-100'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        -Amount(
          number: Decimal.parse('-100'),
          currency: Currency(name: 'CAD'),
        ),
        Amount(
          number: Decimal.parse('100'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        -Amount(
          number: Decimal.zero,
          currency: Currency(name: 'CAD'),
        ),
        Amount(
          number: Decimal.zero,
          currency: Currency(name: 'CAD'),
        ),
      );
    });

    test('mul and div scale the number', () {
      final Amount amount = Amount(
        number: Decimal.parse('100'),
        currency: Currency(name: 'CAD'),
      );
      expect(
        Amount.mul(amount, Decimal.parse('1.021')),
        Amount(
          number: Decimal.parse('102.1'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        Amount.div(amount, Decimal.parse('5')),
        Amount(
          number: Decimal.parse('20'),
          currency: Currency(name: 'CAD'),
        ),
      );
    });

    test('add and sub require matching currencies', () {
      expect(
        Amount.add(
          Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'CAD'),
          ),
          Amount(
            number: Decimal.parse('17.02'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Amount(
          number: Decimal.parse('117.02'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        () => Amount.add(
          Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'USD'),
          ),
          Amount(
            number: Decimal.parse('17.02'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        Amount.sub(
          Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'CAD'),
          ),
          Amount(
            number: Decimal.parse('17.02'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Amount(
          number: Decimal.parse('82.98'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        () => Amount.sub(
          Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'USD'),
          ),
          Amount(
            number: Decimal.parse('17.02'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('abs returns non-negative units', () {
      expect(
        Amount.abs(
          Amount(
            number: Decimal.parse('82.98'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Amount(
          number: Decimal.parse('82.98'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        Amount.abs(
          Amount(
            number: Decimal.zero,
            currency: Currency(name: 'CAD'),
          ),
        ),
        Amount(
          number: Decimal.zero,
          currency: Currency(name: 'CAD'),
        ),
      );
      expect(
        Amount.abs(
          Amount(
            number: Decimal.parse('-82.98'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Amount(
          number: Decimal.parse('82.98'),
          currency: Currency(name: 'CAD'),
        ),
      );
    });
  });
}
