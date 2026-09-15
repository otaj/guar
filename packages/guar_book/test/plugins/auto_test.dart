// Port of beancount.plugins.auto and implicit_prices coverage.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('implicit_prices adds prices from @ and non-reducing costs', () {
    final ledger = booked(
      'plugin "beancount.plugins.implicit_prices"\n'
      '2014-01-01 open Assets:Cash\n'
      '2014-01-01 open Assets:Foreign\n'
      '2014-01-01 open Assets:Shares\n'
      '2014-01-01 open Equity:Opening\n'
      '2014-02-01 *\n'
      '  Assets:Foreign   100 CAD @ 1.10 USD\n'
      '  Assets:Cash     -110 USD\n'
      '2014-03-01 *\n'
      '  Assets:Shares   10 HOOL {500.00 USD}\n'
      '  Assets:Cash  -5000.00 USD\n',
    );
    final prices = [
      for (final d in ledger)
        if (d.body case PriceBody(:final currency, :final amount))
          '${currency.name} ${amount.number} ${amount.currency.name}',
    ];
    expect(prices, containsAll(['CAD 1.1 USD', 'HOOL 500 USD']));
  });

  test('auto meta-plugin runs auto_accounts then implicit_prices', () {
    final ledger = booked(
      'plugin "beancount.plugins.auto"\n'
      '2014-02-01 *\n'
      '  Assets:Cash   100 CAD @ 1.10 USD\n'
      '  Equity:Open  -110 USD\n',
    );
    expect(ledger.any((d) => d.body is OpenBody), isTrue);
    expect(ledger.any((d) => d.body is PriceBody), isTrue);
  });
}
