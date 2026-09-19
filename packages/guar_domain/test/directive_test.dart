// Booked open/transaction/posting bodies from the costs-and-prices fixture.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  test('booked cost per-unit transaction has complete units and dated cost', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Account cash = account('Assets:NZ:Cash', AccountType.assets);
    final Account shares = account('Assets:Shares:IBM', AccountType.assets);
    final Transaction txn = Transaction(
      origin: origin,
      flag: const Flag.special(SpecialFlag.asterisk),
      narration: 'cost per-unit',
      postings: <Posting>[
        Posting(
          origin: origin,
          account: shares,
          units: amount('5', 'IBM'),
          cost: cost('300.00', 'NZD', BeanDate(year: 2025, month: 3, day: 1)),
        ),
        Posting(origin: origin, account: cash, units: amount('-1500.00', 'NZD')),
      ],
    );
    final Directive directive = Directive(
      origin: origin,
      date: BeanDate(year: 2025, month: 3, day: 1),
      body: DirectiveBody.transaction(txn),
    );

    expect(directive.date, BeanDate(year: 2025, month: 3, day: 1));
    final TransactionBody body = directive.body as TransactionBody;
    expect(body.value.narration, 'cost per-unit');
    expect(body.value.postings.first.units, amount('5', 'IBM'));
    expect(body.value.postings.first.cost!.date, BeanDate(year: 2025, month: 3, day: 1));
    expect(body.value.postings.last.price, isNull);
  });

  test('booked @@ price becomes per-unit price amount', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Transaction txn = Transaction(
      origin: origin,
      flag: const Flag.special(SpecialFlag.asterisk),
      narration: 'price total',
      postings: <Posting>[
        Posting(
          origin: origin,
          account: account('Assets:UK:Cash', AccountType.assets),
          units: amount('-197.00', 'GBP'),
          price: amount('1.9369035532994923857868020305', 'NZD'),
        ),
        Posting(origin: origin, account: account('Assets:NZ:Cash', AccountType.assets), units: amount('381.57', 'NZD')),
      ],
    );

    expect(txn.postings.first.price, amount('1.9369035532994923857868020305', 'NZD'));
    expect(txn.postings.first.units, amount('-197.00', 'GBP'));
  });

  test('open and price directive bodies', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Directive open = Directive(
      origin: origin,
      date: BeanDate(year: 2025, month: 1, day: 1),
      body: DirectiveBody.open(account: account('Assets:UK:Cash', AccountType.assets)),
    );
    final Directive price = Directive(
      origin: origin,
      date: BeanDate(year: 2013, month: 6, day: 1),
      body: DirectiveBody.price(
        currency: Currency(name: 'USD'),
        amount: amount('1.10', 'CAD'),
      ),
    );
    expect((open.body as OpenBody).account.name, 'Assets:UK:Cash');
    expect((price.body as PriceBody).amount, amount('1.10', 'CAD'));
  });

  test('budget directive body holds account, interval, and amount', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Directive budget = Directive(
      origin: origin,
      date: BeanDate(year: 2014, month: 2, day: 10),
      body: DirectiveBody.budget(
        account: account('Expenses:Groceries', AccountType.expenses),
        interval: BudgetInterval.monthly,
        amount: amount('40.00', 'EUR'),
      ),
    );
    final BudgetBody body = budget.body as BudgetBody;
    expect(body.account.name, 'Expenses:Groceries');
    expect(body.interval, BudgetInterval.monthly);
    expect(body.amount, amount('40.00', 'EUR'));
  });

  test('budget-off directive body holds the account and optional currency', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Directive off = Directive(
      origin: origin,
      date: BeanDate(year: 2016, month: 6, day: 1),
      body: DirectiveBody.budgetOff(account: account('Expenses:Books', AccountType.expenses)),
    );
    expect((off.body as BudgetOffBody).account.name, 'Expenses:Books');
    expect((off.body as BudgetOffBody).currency, isNull);

    final Directive eur = Directive(
      origin: origin,
      date: BeanDate(year: 2016, month: 6, day: 1),
      body: DirectiveBody.budgetOff(
        account: account('Expenses:Books', AccountType.expenses),
        currency: Currency(name: 'EUR'),
      ),
    );
    expect((eur.body as BudgetOffBody).currency?.name, 'EUR');
  });
}
