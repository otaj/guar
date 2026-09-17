// Port of beancount.plugins.nounused tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags only the account that is never referenced', () {
    expect(
      messages(
        'plugin "beancount.plugins.nounused"\n'
        '2014-01-01 open  Assets:Account1\n'
        '2014-01-01 open  Assets:Account2\n'
        '2014-01-01 open  Assets:Account3\n'
        '2014-01-01 open  Equity:Opening-Balances\n'
        '2014-02-01 *\n'
        '  Assets:Account1            1 USD\n'
        '  Assets:Account2            1 USD\n'
        '  Equity:Opening-Balances   -2 USD\n'
        '2014-06-01 close Assets:Account2\n',
      ),
      ["Unused account 'Assets:Account3'"],
    );
  });

  test('accepts a ledger where every open is referenced', () {
    expect(
      messages(
        'plugin "beancount.plugins.nounused"\n'
        '2014-01-01 open  Assets:Account1\n'
        '2014-01-01 open  Equity:Opening-Balances\n'
        '2014-02-01 *\n'
        '  Assets:Account1            1 USD\n'
        '  Equity:Opening-Balances   -1 USD\n',
      ),
      isEmpty,
    );
  });
}
