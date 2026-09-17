// Port of beancount.plugins.check_commodity tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags every undeclared commodity once', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_commodity"\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 CAD\n'
        '  Assets:Other         -1.00 USD @ 1.00 CAD\n',
      ),
      [
        "Missing Commodity directive for 'CAD' in 'Assets:Other'",
        "Missing Commodity directive for 'USD' in 'Assets:Other'",
      ],
    );
  });

  test('flags a commodity only used in a balance assertion', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_commodity"\n'
        '2000-01-01 commodity USD\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2012-01-01 balance Expenses:Restaurant   0.00 CAD\n',
      ),
      ["Missing Commodity directive for 'CAD' in 'Expenses:Restaurant'"],
    );
  });

  test('accepts a ledger declaring every commodity', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_commodity"\n'
        '2000-01-01 commodity USD\n'
        '2000-01-01 commodity CAD\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2012-01-01 balance Expenses:Restaurant   0.00 CAD\n',
      ),
      isEmpty,
    );
  });

  test('honours the account/currency ignore patterns, including prices', () {
    for (final pair in [
      ('.*', '.*'),
      ('Assets:Options', '.*'),
      ('.*', 'QQQ_.*'),
      ('Assets:.*Options', r'QQQ_[0-9]{6}[CP][0-9]+'),
    ]) {
      expect(
        messages(
          'plugin "beancount.plugins.check_commodity" "{\'${pair.$1}\': \'${pair.$2}\'}"\n'
          '2000-01-01 commodity USD\n'
          '2011-01-01 open Assets:Cash\n'
          '2011-01-01 open Assets:Options\n'
          '2011-05-17 * "Something"\n'
          '  Assets:Options     -100 QQQ_041621C341 {1.470 USD}\n'
          '  Assets:Cash      147.00 USD\n'
          '2011-05-19 price QQQ_041621C341   1.33 USD\n',
        ),
        isEmpty,
        reason: 'patterns ${pair.$1} / ${pair.$2}',
      );
    }
  });

  test('rejects a configuration that is not a dict', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_commodity" "[1, 2]"\n'
        '2000-01-01 commodity USD\n',
      ),
      ['Invalid configuration for check_commodity plugin; skipping.'],
    );
  });
}
