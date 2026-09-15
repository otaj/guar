// Port of beancount.plugins.pedantic tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('accepts a ledger that satisfies every strict check', () {
    expect(
      messages(
        'plugin "beancount.plugins.pedantic"\n'
        '2000-01-01 commodity USD\n'
        '2000-01-01 open Assets:Checking\n'
        '2000-01-01 open Equity:Opening\n'
        '2000-02-01 * "Something"\n'
        '  Assets:Checking   100.00 USD\n'
        '  Equity:Opening   -100.00 USD\n',
      ),
      isEmpty,
    );
  });

  test('reports findings from several bundled checks at once', () {
    final found = messages(
      'plugin "beancount.plugins.pedantic"\n'
      '2000-01-01 open Assets:Checking\n'
      '2000-01-01 open Assets:Unused\n'
      '2000-01-01 open Equity:Opening\n'
      '2000-02-01 * "Something"\n'
      '  Assets:Checking   100.00 USD\n'
      '  Equity:Opening   -100.00 USD\n',
    );
    expect(found, contains("Missing Commodity directive for 'USD' in 'Assets:Checking'"));
    expect(found, contains("Unused account 'Assets:Unused'"));
  });
}
