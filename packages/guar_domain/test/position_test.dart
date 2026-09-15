// Ports of beancount.core.position_test for booked Cost and Position.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Account', () {
    test('carries name and account type', () {
      final account = Account(name: 'Assets:Bank:Current', type: AccountType.assets);
      expect(account.name, 'Assets:Bank:Current');
      expect(account.type, AccountType.assets);
      expect(Account(name: 'Income:Salary', type: AccountType.income), isNot(account));
    });
  });

  group('Cost', () {
    test('toString includes detail by default', () {
      final cost = Cost(
        number: Decimal.parse('101.23'),
        currency: Currency(name: 'USD'),
        date: BeanDate(year: 2015, month: 9, day: 6),
        label: 'f4412439c31b',
      );
      expect(cost.toString(), '101.23 USD, 2015-09-06, "f4412439c31b"');
      expect(cost.toString(detail: false), '101.23 USD');
    });
  });

  group('Position', () {
    final hool = Amount(
      number: Decimal.parse('2.2'),
      currency: Currency(name: 'HOOL'),
    );
    final cost = Cost(
      number: Decimal.parse('532.43'),
      currency: Currency(name: 'USD'),
      date: BeanDate(year: 2014, month: 6, day: 15),
    );

    test('holds units and optional cost', () {
      expect(Position(units: hool), Position(units: hool));
      expect(Position(units: hool, cost: cost), Position(units: hool, cost: cost));
    });

    test('toString renders units and cost', () {
      final pos = Position(units: hool, cost: cost);
      expect(pos.toString(), '2.2 HOOL {532.43 USD, 2014-06-15}');
      expect(pos.toString(detail: false), '2.2 HOOL {532.43 USD}');
    });

    test('neg and abs preserve cost', () {
      final pos = Position(
        units: Amount(
          number: Decimal.parse('7'),
          currency: Currency(name: 'CAD'),
        ),
      );
      expect((-pos).units.number, Decimal.parse('-7'));
      expect(pos.absolute.units.number, Decimal.parse('7'));
      expect(
        Position(
          units: Amount(
            number: Decimal.parse('-7'),
            currency: Currency(name: 'CAD'),
          ),
        ).absolute.units.number,
        Decimal.parse('7'),
      );
    });

    test('mul scales units and keeps cost', () {
      final pos = Position(
        units: Amount(
          number: Decimal.parse('2'),
          currency: Currency(name: 'HOOL'),
        ),
        cost: Cost(
          number: Decimal.parse('100.00'),
          currency: Currency(name: 'USD'),
          date: BeanDate(year: 2014, month: 6, day: 15),
        ),
      );
      expect(
        pos * Decimal.parse('3'),
        Position(
          units: Amount(
            number: Decimal.parse('6'),
            currency: Currency(name: 'HOOL'),
          ),
          cost: Cost(
            number: Decimal.parse('100.00'),
            currency: Currency(name: 'USD'),
            date: BeanDate(year: 2014, month: 6, day: 15),
          ),
        ),
      );
    });

    test('sort is currency then cost then units', () {
      final positions = [
        Position(
          units: Amount(
            number: Decimal.parse('50'),
            currency: Currency(name: 'ZZZ'),
          ),
        ),
        Position(
          units: Amount(
            number: Decimal.parse('101'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Position(
          units: Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'CAD'),
          ),
        ),
        Position(
          units: Amount(
            number: Decimal.parse('201'),
            currency: Currency(name: 'USD'),
          ),
        ),
        Position(
          units: Amount(
            number: Decimal.parse('200'),
            currency: Currency(name: 'USD'),
          ),
        ),
      ]..sort(Position.compare);
      expect(positions.map((p) => p.units.toString()).toList(), ['100 CAD', '101 CAD', '200 USD', '201 USD', '50 ZZZ']);
    });

    test('isNegativeAtCost and currencyPair', () {
      final long = Position(
        units: Amount(
          number: Decimal.parse('1'),
          currency: Currency(name: 'USD'),
        ),
        cost: Cost(
          number: Decimal.parse('10'),
          currency: Currency(name: 'AUD'),
          date: BeanDate(year: 2014, month: 6, day: 15),
        ),
      );
      final short = Position(units: -long.units, cost: long.cost);
      expect(long.isNegativeAtCost, isFalse);
      expect(short.isNegativeAtCost, isTrue);
      expect(long.currencyPair, ('USD', 'AUD'));
      expect(
        Position(
          units: Amount(
            number: Decimal.parse('100'),
            currency: Currency(name: 'USD'),
          ),
        ).currencyPair,
        ('USD', null),
      );
    });
  });
}
