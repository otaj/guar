// Ports of Fava budget calculations plus booked actuals for the same interval.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:rational/rational.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

final _origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));

BeanDate d(int year, int month, int day) => BeanDate(year: year, month: month, day: day);

Decimal share(String number, int days) => shares(number, [days]);

Decimal shares(String number, List<int> days) {
  var total = Rational.zero;
  for (final length in days) {
    total += Decimal.parse(number) / Decimal.fromInt(length);
  }
  return total.toDecimal(scaleOnInfinitePrecision: 28);
}

Directive budget(BeanDate date, String name, BudgetInterval interval, String number, String currency) {
  return Directive(
    origin: _origin,
    date: date,
    body: DirectiveBody.budget(
      account: account(name, AccountType.expenses),
      interval: interval,
      amount: amount(number, currency),
    ),
  );
}

Directive txn(BeanDate date, String name, String number, String currency, {int line = 1}) {
  final origin = Origin.source(BeanLocation(linenoBegin: line, linenoEnd: line));
  return Directive(
    origin: origin,
    date: date,
    body: DirectiveBody.transaction(
      Transaction(
        origin: origin,
        flag: const Flag.special(SpecialFlag.asterisk),
        postings: [
          Posting(origin: origin, account: account(name, AccountType.expenses), units: amount(number, currency)),
          Posting(
            origin: origin,
            account: account('Assets:Cash', AccountType.assets),
            units: amount(number.startsWith('-') ? number.substring(1) : '-$number', currency),
          ),
        ],
      ),
    ),
  );
}

Amount? eur(List<Amount> amounts) {
  for (final amount in amounts) {
    if (amount.currency.name == 'EUR') return amount;
  }
  return null;
}

Amount? named(List<Amount> amounts, String currency) {
  for (final amount in amounts) {
    if (amount.currency.name == currency) return amount;
  }
  return null;
}

void main() {
  test('weekly budgets stay active by currency until replaced', () {
    final map = BudgetMap.build([
      budget(d(2016, 1, 1), 'Expenses:Groceries', BudgetInterval.weekly, '100.00', 'CNY'),
      budget(d(2016, 6, 1), 'Expenses:Groceries', BudgetInterval.weekly, '10.00', 'EUR'),
    ]);
    expect(map.allowed('Expenses', d(2016, 6, 1), d(2016, 6, 8)), isEmpty);

    final allowed = map.allowed('Expenses:Groceries', d(2016, 6, 1), d(2016, 6, 8));
    expect(named(allowed, 'CNY')!.number, Decimal.parse('100'));
    expect(named(allowed, 'EUR')!.number, Decimal.parse('10'));
  });

  test('daily budgets prorate by civil day and ignore days before they start', () {
    final map = BudgetMap.build([budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '2.5', 'EUR')]);
    expect(named(map.allowed('Expenses:Books', d(2010, 2, 1), d(2010, 2, 2)), 'EUR'), isNull);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, Decimal.parse('2.5'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 3)))!.number, Decimal.parse('5.0'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 9, 2), d(2016, 9, 3)))!.number, Decimal.parse('2.5'));
    expect(eur(map.allowed('Expenses:Books', d(2018, 12, 31), d(2019, 1, 1)))!.number, Decimal.parse('2.5'));
  });

  test('weekly budgets divide by seven days', () {
    final map = BudgetMap.build([budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.weekly, '21', 'EUR')]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('21', 7));
    expect(eur(map.allowed('Expenses:Books', d(2016, 9, 1), d(2016, 9, 2)))!.number, share('21', 7));
  });

  test('monthly budgets divide by the actual length of that month', () {
    final map = BudgetMap.build([budget(d(2014, 5, 1), 'Expenses:Books', BudgetInterval.monthly, '100', 'EUR')]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('100', 31));
    expect(eur(map.allowed('Expenses:Books', d(2016, 2, 1), d(2016, 2, 2)))!.number, share('100', 29));
    expect(eur(map.allowed('Expenses:Books', d(2018, 3, 31), d(2018, 4, 1)))!.number, share('100', 31));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 6, 1)))!.number, Decimal.parse('100'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 2)))!.number, shares('100', [31, 30]));
  });

  test('quarterly budgets divide by the actual length of that quarter', () {
    final map = BudgetMap.build([budget(d(2014, 5, 1), 'Expenses:Books', BudgetInterval.quarterly, '123456.7', 'EUR')]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('123456.7', 91));
    expect(eur(map.allowed('Expenses:Books', d(2016, 8, 15), d(2016, 8, 16)))!.number, share('123456.7', 92));
  });

  test('yearly budgets divide by the actual length of that year', () {
    final map = BudgetMap.build([budget(d(2010, 1, 1), 'Expenses:Books', BudgetInterval.yearly, '99999.87', 'EUR')]);
    expect(eur(map.allowed('Expenses:Books', d(2011, 2, 1), d(2011, 2, 2)))!.number, share('99999.87', 365));
    expect(eur(map.allowed('Expenses:Books', d(2012, 2, 1), d(2012, 2, 2)))!.number, share('99999.87', 366));
  });

  test('child budgets sum with the requested account', () {
    final map = BudgetMap.build([
      budget(d(2017, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'USD'),
      budget(d(2017, 1, 1), 'Expenses:Books:Notebooks', BudgetInterval.daily, '2.00', 'USD'),
    ]);
    expect(
      named(map.allowed('Expenses', d(2017, 1, 1), d(2017, 1, 2), includeChildren: true), 'USD')!.number,
      Decimal.parse('12.00'),
    );
    expect(
      named(map.allowed('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2), includeChildren: true), 'USD')!.number,
      Decimal.parse('12.00'),
    );
    expect(
      named(
        map.allowed('Expenses:Books:Notebooks', d(2017, 1, 1), d(2017, 1, 2), includeChildren: true),
        'USD',
      )!.number,
      Decimal.parse('2.00'),
    );
    expect(map.allowed('Expenses', d(2017, 1, 1), d(2017, 1, 2)), isEmpty);
  });

  test('actuals sum booked units in [begin, end) by account', () {
    final map = BudgetMap.build([
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR'),
      txn(d(2016, 5, 2), 'Expenses:Books', '3.00', 'EUR'),
      txn(d(2016, 5, 3), 'Expenses:Books', '9.00', 'EUR'),
    ]);
    expect(eur(map.actual('Expenses:Books', d(2016, 5, 1), d(2016, 5, 3)))!.number, Decimal.parse('7.00'));
    expect(eur(map.actual('Expenses:Books', d(2016, 5, 3), d(2016, 5, 4)))!.number, Decimal.parse('9.00'));
    expect(map.actual('Expenses:Books', d(2016, 4, 1), d(2016, 5, 1)), isEmpty);
  });

  test('actuals with children include descendant postings under a budgeted account', () {
    final map = BudgetMap.build([
      budget(d(2017, 1, 1), 'Expenses:Books', BudgetInterval.daily, '20.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Books', '5.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Books:Notebooks', '3.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Fun', '7.00', 'USD'),
    ]);
    expect(named(map.actual('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number, Decimal.parse('5.00'));
    expect(
      named(map.actual('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2), includeChildren: true), 'USD')!.number,
      Decimal.parse('8.00'),
    );
    expect(map.actual('Expenses:Books:Notebooks', d(2017, 1, 1), d(2017, 1, 2)), isEmpty);
    expect(map.actual('Expenses:Fun', d(2017, 1, 1), d(2017, 1, 2)), isEmpty);
    expect(
      named(map.actual('Expenses', d(2017, 1, 1), d(2017, 1, 2), includeChildren: true), 'USD')!.number,
      Decimal.parse('8.00'),
    );
  });

  test('period reports remaining and whether actuals stay within the prorated budget', () {
    final map = BudgetMap.build([
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR'),
      txn(d(2016, 5, 2), 'Expenses:Books', '3.00', 'EUR'),
    ]);

    final under = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 3));
    expect(under.within, isTrue);
    expect(under.currencies, hasLength(1));
    expect(under.currencies.single.budget.number, Decimal.parse('20.00'));
    expect(under.currencies.single.actual.number, Decimal.parse('7.00'));
    expect(under.currencies.single.remaining.number, Decimal.parse('13.00'));

    final over = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(over.within, isTrue);
    expect(map.period('Expenses:Books', d(2016, 5, 2), d(2016, 5, 3)).within, isTrue);

    final overMap = BudgetMap.build([
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '5.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '6.00', 'EUR'),
    ]);
    final exceeded = overMap.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(exceeded.within, isFalse);
    expect(exceeded.currencies.single.remaining.number, Decimal.parse('-1.00'));
  });

  test('unbudgeted accounts are absent from the map', () {
    final map = BudgetMap.build([
      budget(d(2016, 5, 1), 'Expenses:Groceries', BudgetInterval.weekly, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '1.00', 'EUR'),
    ]);
    expect(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    expect(map.actual('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    expect(map.actual('Assets:Cash', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    final period = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(period.within, isNull);
    expect(period.currencies, isEmpty);
    expect(period.warnings, isEmpty);
  });

  test('actuals in an unbudgeted currency are omitted from the budgeted currency and warned', () {
    final map = BudgetMap.build([
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR', line: 2),
      txn(d(2016, 5, 1), 'Expenses:Books', '9.00', 'USD', line: 3),
    ]);

    final period = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(period.within, isTrue);
    expect(period.currencies, hasLength(1));
    expect(period.currencies.single.budget.currency.name, 'EUR');
    expect(period.currencies.single.actual.number, Decimal.parse('4.00'));
    expect(period.warnings, hasLength(1));
    expect(period.warnings.single.location.linenoBegin, 3);
    expect(period.warnings.single.message, 'Ignored 9 USD posting on Expenses:Books; no budget in USD');
    expect(named(map.actual('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)), 'USD')!.number, Decimal.parse('9.00'));
  });

  test('a later budget for the same currency replaces the earlier one from that day', () {
    final map = BudgetMap.build([
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 6, 1), 'Expenses:Books', BudgetInterval.daily, '1.00', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 1)))!.number, Decimal.parse('10.00'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2)))!.number, Decimal.parse('1.00'));
  });
}
