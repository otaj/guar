// Booked open/transaction/posting bodies from the costs-and-prices fixture.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  test('booked cost per-unit transaction has complete units and dated cost', () {
    const origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final cash = account('Assets:NZ:Cash', AccountType.assets);
    final shares = account('Assets:Shares:IBM', AccountType.assets);
    final txn = Transaction(
      origin: origin,
      flag: const Flag.special(SpecialFlag.asterisk),
      narration: 'cost per-unit',
      postings: [
        Posting(
          origin: origin,
          account: shares,
          units: amount('5', 'IBM'),
          cost: cost('300.00', 'NZD', const BeanDate(year: 2025, month: 3, day: 1)),
        ),
        Posting(origin: origin, account: cash, units: amount('-1500.00', 'NZD')),
      ],
    );
    final directive = Directive(
      origin: origin,
      date: const BeanDate(year: 2025, month: 3, day: 1),
      body: DirectiveBody.transaction(txn),
    );

    expect(directive.date, const BeanDate(year: 2025, month: 3, day: 1));
    final body = directive.body as TransactionBody;
    expect(body.value.narration, 'cost per-unit');
    expect(body.value.postings.first.units, amount('5', 'IBM'));
    expect(body.value.postings.first.cost!.date, const BeanDate(year: 2025, month: 3, day: 1));
    expect(body.value.postings.last.price, isNull);
  });

  test('booked @@ price becomes per-unit price amount', () {
    const origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final txn = Transaction(
      origin: origin,
      flag: const Flag.special(SpecialFlag.asterisk),
      narration: 'price total',
      postings: [
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
    const origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final open = Directive(
      origin: origin,
      date: const BeanDate(year: 2025, month: 1, day: 1),
      body: DirectiveBody.open(account: account('Assets:UK:Cash', AccountType.assets)),
    );
    final price = Directive(
      origin: origin,
      date: const BeanDate(year: 2013, month: 6, day: 1),
      body: DirectiveBody.price(
        currency: const Currency(name: 'USD'),
        amount: amount('1.10', 'CAD'),
      ),
    );
    expect((open.body as OpenBody).account.name, 'Assets:UK:Cash');
    expect((price.body as PriceBody).amount, amount('1.10', 'CAD'));
  });
}
