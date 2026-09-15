// Port of beancount.plugins.unique_prices tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags disagreeing prices for the same day and pair', () {
    expect(
      messages(
        'plugin "beancount.plugins.unique_prices"\n'
        '2000-01-01 price HOOL 500.00 USD\n'
        '2000-01-01 price HOOL 500.01 USD\n',
      ),
      contains('Disagreeing price entries'),
    );
  });

  test('accepts repeated identical prices', () {
    expect(
      messages(
        'plugin "beancount.plugins.unique_prices"\n'
        '2000-01-01 price HOOL 500.00 USD\n'
        '2000-01-01 price HOOL 500.00 USD\n',
      ),
      isEmpty,
    );
  });

  test('flags disagreeing prices synthesized from costs', () {
    expect(
      messages(
        'plugin "beancount.plugins.implicit_prices"\n'
        'plugin "beancount.plugins.unique_prices"\n'
        '2014-01-01 open Income:Misc\n'
        '2014-01-01 open Assets:Account1\n'
        '2014-01-01 open Liabilities:Account1\n'
        '2014-01-15 *\n'
        '  Income:Misc        -201 USD\n'
        '  Assets:Account1       1 HOUSE {100 USD}\n'
        '  Liabilities:Account1  1 HOUSE {101 USD}\n',
      ),
      contains('Disagreeing price entries'),
    );
  });
}
