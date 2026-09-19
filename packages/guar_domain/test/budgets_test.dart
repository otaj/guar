// Ports of Fava budget calculations plus booked actuals for the same interval.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:rational/rational.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

BeanDate d(int year, int month, int day) => BeanDate(year: year, month: month, day: day);

Decimal share(String number, int days) => shares(number, <int>[days]);

Decimal shares(String number, List<int> days) {
  Rational total = Rational.zero;
  for (final int length in days) {
    total += Decimal.parse(number) / Decimal.fromInt(length);
  }
  return total.toDecimal(scaleOnInfinitePrecision: 28);
}

Directive budget(BeanDate date, String name, BudgetInterval interval, String number, String currency, {int line = 1}) =>
    Directive(
      origin: Origin.source(BeanLocation(linenoBegin: line, linenoEnd: line)),
      date: date,
      body: DirectiveBody.budget(
        account: Account.budget(name: name, type: AccountType.expenses),
        interval: interval,
        amount: amount(number, currency),
      ),
    );

Directive budgetOff(BeanDate date, String name, {String? currency, int line = 1}) => Directive(
  origin: Origin.source(BeanLocation(linenoBegin: line, linenoEnd: line)),
  date: date,
  body: DirectiveBody.budgetOff(
    account: Account.budget(name: name, type: AccountType.expenses),
    currency: currency == null ? null : Currency(name: currency),
  ),
);

Directive txn(BeanDate date, String name, String number, String currency, {int line = 1}) {
  final Origin origin = Origin.source(BeanLocation(linenoBegin: line, linenoEnd: line));
  return Directive(
    origin: origin,
    date: date,
    body: DirectiveBody.transaction(
      Transaction(
        origin: origin,
        flag: const Flag.special(SpecialFlag.asterisk),
        postings: <Posting>[
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
  for (final Amount amount in amounts) {
    if (amount.currency.name == 'EUR') return amount;
  }
  return null;
}

Amount? named(List<Amount> amounts, String currency) {
  for (final Amount amount in amounts) {
    if (amount.currency.name == currency) return amount;
  }
  return null;
}

void main() {
  test('weekly budgets stay active by currency until replaced', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Groceries', BudgetInterval.weekly, '100.00', 'CNY'),
      budget(d(2016, 6, 1), 'Expenses:Groceries', BudgetInterval.weekly, '10.00', 'EUR'),
    ]);
    expect(named(map.allowed('Expenses', d(2016, 6, 1), d(2016, 6, 8)), 'CNY')!.number, Decimal.parse('100'));
    expect(named(map.allowed('Expenses', d(2016, 6, 1), d(2016, 6, 8)), 'EUR')!.number, Decimal.parse('10'));
    expect(map.allowed('Expenses', d(2016, 6, 1), d(2016, 6, 8), includeChildren: false), isEmpty);

    final List<Amount> allowed = map.allowed('Expenses:Groceries', d(2016, 6, 1), d(2016, 6, 8));
    expect(named(allowed, 'CNY')!.number, Decimal.parse('100'));
    expect(named(allowed, 'EUR')!.number, Decimal.parse('10'));
  });

  test('daily budgets prorate by civil day and ignore days before they start', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '2.5', 'EUR'),
    ]);
    expect(named(map.allowed('Expenses:Books', d(2010, 2, 1), d(2010, 2, 2)), 'EUR'), isNull);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, Decimal.parse('2.5'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 3)))!.number, Decimal.parse('5.0'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 9, 2), d(2016, 9, 3)))!.number, Decimal.parse('2.5'));
    expect(eur(map.allowed('Expenses:Books', d(2018, 12, 31), d(2019, 1, 1)))!.number, Decimal.parse('2.5'));
  });

  test('weekly budgets divide by seven days', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.weekly, '21', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('21', 7));
    expect(eur(map.allowed('Expenses:Books', d(2016, 9, 1), d(2016, 9, 2)))!.number, share('21', 7));
  });

  test('monthly budgets divide by the actual length of that month', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2014, 5, 1), 'Expenses:Books', BudgetInterval.monthly, '100', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('100', 31));
    expect(eur(map.allowed('Expenses:Books', d(2016, 2, 1), d(2016, 2, 2)))!.number, share('100', 29));
    expect(eur(map.allowed('Expenses:Books', d(2018, 3, 31), d(2018, 4, 1)))!.number, share('100', 31));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 6, 1)))!.number, Decimal.parse('100'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 2)))!.number, shares('100', <int>[31, 30]));
  });

  test('quarterly budgets divide by the actual length of that quarter', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2014, 5, 1), 'Expenses:Books', BudgetInterval.quarterly, '123456.7', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, share('123456.7', 91));
    expect(eur(map.allowed('Expenses:Books', d(2016, 8, 15), d(2016, 8, 16)))!.number, share('123456.7', 92));
  });

  test('yearly budgets divide by the actual length of that year', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2010, 1, 1), 'Expenses:Books', BudgetInterval.yearly, '99999.87', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2011, 2, 1), d(2011, 2, 2)))!.number, share('99999.87', 365));
    expect(eur(map.allowed('Expenses:Books', d(2012, 2, 1), d(2012, 2, 2)))!.number, share('99999.87', 366));
  });

  test('child budgets sum with the requested account', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2017, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'USD'),
      budget(d(2017, 1, 1), 'Expenses:Books:Notebooks', BudgetInterval.daily, '2.00', 'USD'),
    ]);
    expect(named(map.allowed('Expenses', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number, Decimal.parse('12.00'));
    expect(named(map.allowed('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number, Decimal.parse('12.00'));
    expect(
      named(map.allowed('Expenses:Books:Notebooks', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number,
      Decimal.parse('2.00'),
    );
    expect(map.allowed('Expenses', d(2017, 1, 1), d(2017, 1, 2), includeChildren: false), isEmpty);
  });

  test('actuals sum booked units in [begin, end) by account', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
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
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2017, 1, 1), 'Expenses:Books', BudgetInterval.daily, '20.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Books', '5.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Books:Notebooks', '3.00', 'USD'),
      txn(d(2017, 1, 1), 'Expenses:Fun', '7.00', 'USD'),
    ]);
    expect(
      named(map.actual('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2), includeChildren: false), 'USD')!.number,
      Decimal.parse('5.00'),
    );
    expect(named(map.actual('Expenses:Books', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number, Decimal.parse('8.00'));
    expect(map.actual('Expenses:Books:Notebooks', d(2017, 1, 1), d(2017, 1, 2)), isEmpty);
    expect(map.actual('Expenses:Fun', d(2017, 1, 1), d(2017, 1, 2)), isEmpty);
    expect(named(map.actual('Expenses', d(2017, 1, 1), d(2017, 1, 2)), 'USD')!.number, Decimal.parse('8.00'));
  });

  test('period reports remaining and whether actuals stay within the prorated budget', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR'),
      txn(d(2016, 5, 2), 'Expenses:Books', '3.00', 'EUR'),
    ]);

    final BudgetPeriod under = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 3));
    expect(under.within, isTrue);
    expect(under.currencies, hasLength(1));
    expect(under.currencies.single.budget.number, Decimal.parse('20.00'));
    expect(under.currencies.single.actual.number, Decimal.parse('7.00'));
    expect(under.currencies.single.remaining.number, Decimal.parse('13.00'));

    final BudgetPeriod over = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(over.within, isTrue);
    expect(map.period('Expenses:Books', d(2016, 5, 2), d(2016, 5, 3)).within, isTrue);

    final BudgetMap overMap = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '5.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '6.00', 'EUR'),
    ]);
    final BudgetPeriod exceeded = overMap.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(exceeded.within, isFalse);
    expect(exceeded.currencies.single.remaining.number, Decimal.parse('-1.00'));
  });

  test('unbudgeted accounts are absent from the map', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Groceries', BudgetInterval.weekly, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '1.00', 'EUR'),
    ]);
    expect(map.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    expect(map.actual('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    expect(map.actual('Assets:Cash', d(2016, 5, 1), d(2016, 5, 2)), isEmpty);
    final BudgetPeriod period = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(period.within, isNull);
    expect(period.currencies, isEmpty);
    expect(period.warnings, isEmpty);
  });

  test('actuals in an unbudgeted currency are omitted from the budgeted currency and warned', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR', line: 2),
      txn(d(2016, 5, 1), 'Expenses:Books', '9.00', 'USD', line: 3),
    ]);

    final BudgetPeriod period = map.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
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
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 6, 1), 'Expenses:Books', BudgetInterval.daily, '1.00', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 1)))!.number, Decimal.parse('10.00'));
    expect(eur(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2)))!.number, Decimal.parse('1.00'));
  });

  test('off stops every currency on the account from the given date', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.weekly, '70.00', 'USD'),
      budgetOff(d(2016, 6, 1), 'Expenses:Books'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 1)))!.number, Decimal.parse('10.00'));
    expect(named(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 1)), 'USD')!.number, share('70.00', 7));
    expect(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2)), isEmpty);

    final BudgetPeriod after = map.period('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2));
    expect(after.within, isNull);
    expect(after.currencies, isEmpty);

    final BudgetMap onAgain = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budgetOff(d(2016, 6, 1), 'Expenses:Books'),
      budget(d(2016, 7, 1), 'Expenses:Books', BudgetInterval.daily, '3.00', 'EUR'),
    ]);
    expect(onAgain.allowed('Expenses:Books', d(2016, 6, 15), d(2016, 6, 16)), isEmpty);
    expect(eur(onAgain.allowed('Expenses:Books', d(2016, 7, 1), d(2016, 7, 2)))!.number, Decimal.parse('3.00'));
  });

  test('off with a currency stops only that currency', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.weekly, '70.00', 'USD'),
      budgetOff(d(2016, 6, 1), 'Expenses:Books', currency: 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 1)))!.number, Decimal.parse('10.00'));
    expect(named(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2)), 'USD')!.number, share('70.00', 7));
    expect(eur(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2))), isNull);

    final BudgetMap onAgain = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budgetOff(d(2016, 6, 1), 'Expenses:Books', currency: 'EUR'),
      budget(d(2016, 7, 1), 'Expenses:Books', BudgetInterval.daily, '3.00', 'EUR'),
    ]);
    expect(onAgain.allowed('Expenses:Books', d(2016, 6, 15), d(2016, 6, 16)), isEmpty);
    expect(eur(onAgain.allowed('Expenses:Books', d(2016, 7, 1), d(2016, 7, 2)))!.number, Decimal.parse('3.00'));
  });

  test('a zero budget is within only when nothing is spent', () {
    final BudgetMap empty = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '0', 'EUR'),
    ]);
    final BudgetPeriod idle = empty.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(eur(empty.allowed('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)))!.number, Decimal.zero);
    expect(idle.within, isTrue);
    expect(idle.currencies.single.actual.number, Decimal.zero);

    final BudgetMap spent = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '0', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '1.00', 'EUR'),
    ]);
    final BudgetPeriod over = spent.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(over.within, isFalse);
    expect(over.currencies.single.remaining.number, Decimal.parse('-1.00'));
  });

  test('a root account budget covers descendants', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses', BudgetInterval.monthly, '9000', 'USD'),
      txn(d(2016, 1, 15), 'Expenses:Food', '40', 'USD'),
      txn(d(2016, 1, 15), 'Expenses:Food:Cafe', '10', 'USD'),
    ]);
    expect(named(map.allowed('Expenses', d(2016, 1, 1), d(2016, 2, 1)), 'USD')!.number, Decimal.parse('9000'));
    expect(named(map.actual('Expenses', d(2016, 1, 1), d(2016, 2, 1)), 'USD')!.number, Decimal.parse('50'));
    expect(map.allowed('Expenses:Food', d(2016, 1, 1), d(2016, 2, 1)), isEmpty);
    expect(map.actual('Expenses:Food', d(2016, 1, 1), d(2016, 2, 1)), isEmpty);
  });

  test('same-day duplicate budgets keep the later one and warn', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 2),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '4.00', 'EUR', line: 3),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)))!.number, Decimal.parse('4.00'));
    expect(map.warnings, hasLength(1));
    expect(map.warnings.single.location.linenoBegin, 3);
    expect(
      map.warnings.single.message,
      'Duplicate budget for Expenses:Books EUR on 2016-01-01; using the later directive',
    );
    expect(map.period('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)).warnings, hasLength(1));
  });

  test('a range that crosses a replacement is a piecewise sum', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 6, 1), 'Expenses:Books', BudgetInterval.daily, '1.00', 'EUR'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 2)))!.number, Decimal.parse('11.00'));
  });

  test('a range that crosses an off is a piecewise sum', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budgetOff(d(2016, 6, 1), 'Expenses:Books'),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 5, 31), d(2016, 6, 2)))!.number, Decimal.parse('10.00'));
    expect(map.allowed('Expenses:Books', d(2016, 6, 1), d(2016, 6, 2)), isEmpty);
  });

  test('same-day identical budgets do not warn', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 2),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 3),
    ]);
    expect(eur(map.allowed('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)))!.number, Decimal.parse('10.00'));
    expect(map.warnings, isEmpty);
  });

  test('same-day budget and off keep the later directive and warn', () {
    final BudgetMap offLast = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 2),
      budgetOff(d(2016, 1, 1), 'Expenses:Books', currency: 'EUR', line: 3),
    ]);
    expect(offLast.allowed('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)), isEmpty);
    expect(offLast.warnings, hasLength(1));
    expect(offLast.warnings.single.location.linenoBegin, 3);

    final BudgetMap budgetLast = BudgetMap.build(<Directive>[
      budgetOff(d(2016, 1, 1), 'Expenses:Books', currency: 'EUR', line: 2),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 3),
    ]);
    expect(eur(budgetLast.allowed('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)))!.number, Decimal.parse('10.00'));
    expect(budgetLast.warnings, hasLength(1));
    expect(budgetLast.warnings.single.location.linenoBegin, 3);
  });

  test('duplicate warnings stay on the duplicated account', () {
    final BudgetMap map = BudgetMap.build(<Directive>[
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR', line: 2),
      budget(d(2016, 1, 1), 'Expenses:Books', BudgetInterval.daily, '4.00', 'EUR', line: 3),
      budget(d(2016, 1, 1), 'Expenses:Food', BudgetInterval.daily, '5.00', 'EUR', line: 4),
    ]);
    expect(map.period('Expenses:Food', d(2016, 1, 1), d(2016, 1, 2)).warnings, isEmpty);
    expect(map.period('Expenses:Books', d(2016, 1, 1), d(2016, 1, 2)).warnings, hasLength(1));
  });

  test('period is over if any budgeted currency is over', () {
    final BudgetMap mixed = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '5.00', 'USD'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '6.00', 'USD'),
    ]);
    final BudgetPeriod period = mixed.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2));
    expect(period.currencies, hasLength(2));
    expect(
      named(period.currencies.map((BudgetCurrencyStatus row) => row.budget).toList(), 'EUR')!.number,
      Decimal.parse('10.00'),
    );
    expect(period.within, isFalse);

    final BudgetMap under = BudgetMap.build(<Directive>[
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '10.00', 'EUR'),
      budget(d(2016, 5, 1), 'Expenses:Books', BudgetInterval.daily, '5.00', 'USD'),
      txn(d(2016, 5, 1), 'Expenses:Books', '4.00', 'EUR'),
      txn(d(2016, 5, 1), 'Expenses:Books', '5.00', 'USD'),
    ]);
    expect(under.period('Expenses:Books', d(2016, 5, 1), d(2016, 5, 2)).within, isTrue);
  });
}
