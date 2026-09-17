// Port of beancount.plugins.coherent_cost tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags a commodity used both with and without cost', () {
    expect(
      messages(
        'plugin "beancount.plugins.coherent_cost"\n'
        '2014-01-01 open  Assets:Invest:Shares\n'
        '2014-01-01 open  Assets:Invest:Cash\n'
        '2014-01-01 open  Equity:Opening-Balances\n'
        '2014-02-01 *\n'
        '  Assets:Invest:Shares       2 AAPL {40.32 USD}\n'
        '  Assets:Invest:Shares       2 HOOL {700.01 USD}\n'
        '  Assets:Invest:Cash         -1000.00 GBP @ 1.48066 USD\n'
        '2014-03-01 *\n'
        '  Assets:Invest:Shares       -1 AAPL {40.32 USD} @ 44.30 USD\n'
        '  Assets:Invest:Cash\n'
        '2014-03-02 *\n'
        '  Assets:Invest:Shares       1 HOOL @ 720.00 USD\n'
        '  Assets:Invest:Cash\n',
      ),
      ["Currency 'HOOL' is used both with and without cost"],
    );
  });

  test('accepts a ledger keeping held-at-cost commodities separate', () {
    expect(
      messages(
        'plugin "beancount.plugins.coherent_cost"\n'
        '2014-01-01 open  Assets:Invest:Shares\n'
        '2014-01-01 open  Assets:Invest:Cash\n'
        '2014-02-01 *\n'
        '  Assets:Invest:Shares       2 AAPL {40.32 USD}\n'
        '  Assets:Invest:Cash      -80.64 USD\n',
      ),
      isEmpty,
    );
  });
}
