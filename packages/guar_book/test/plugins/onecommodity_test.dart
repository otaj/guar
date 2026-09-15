// Port of beancount.plugins.onecommodity tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags an account posted in two currencies', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" ""\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 CAD\n'
        '  Assets:Other         -1.00 USD @ 1.00 CAD\n',
      ),
      ["More than one currency in account 'Expenses:Restaurant': USD,CAD"],
    );
  });

  test('flags a second currency introduced by a balance assertion', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" ""\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2012-01-01 balance Expenses:Restaurant   0.00 CAD\n',
      ),
      ["More than one currency in account 'Expenses:Restaurant': USD,CAD"],
    );
  });

  test('skips accounts declaring several currencies on their open', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" ""\n'
        '2011-01-01 open Expenses:Restaurant  CAD,USD\n'
        '2011-01-01 open Assets:Other         CAD,USD\n'
        '2011-05-17 * ""\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2011-05-18 * ""\n'
        '  Expenses:Restaurant   1.00 CAD\n'
        '  Assets:Other         -1.00 CAD\n',
      ),
      isEmpty,
    );
  });

  test('restricts checks to accounts matching the config regexp', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" "Assets:.*"\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 CAD\n'
        '  Assets:Other         -1.00 USD @ 1.00 CAD\n',
      ),
      isEmpty,
    );
  });

  test('honours onecommodity: FALSE on the open directive', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" ""\n'
        '2011-01-01 open Expenses:Restaurant\n'
        '  onecommodity: FALSE\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 USD\n'
        '  Assets:Other         -1.00 USD\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Restaurant   1.00 CAD\n'
        '  Assets:Other         -1.00 USD @ 1.00 CAD\n',
      ),
      isEmpty,
    );
  });

  test('flags two cost currencies on the same account', () {
    expect(
      messages(
        'plugin "beancount.plugins.onecommodity" ""\n'
        '2011-01-01 open Assets:Shares\n'
        '2011-01-01 open Assets:Cash\n'
        '2011-05-17 * ""\n'
        '  Assets:Shares    1 HOOL {100.00 USD}\n'
        '  Assets:Cash   -100.00 USD\n'
        '2011-05-18 * ""\n'
        '  Assets:Shares    1 HOOL {120.00 CAD}\n'
        '  Assets:Cash   -120.00 CAD\n',
      ),
      contains("More than one cost currency in account 'Assets:Shares': USD,CAD"),
    );
  });
}
