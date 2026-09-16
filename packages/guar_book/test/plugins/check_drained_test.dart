// Port of beancount.plugins.check_drained tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('does nothing without the plugin', () {
    expect(
      balances(
        booked(
          '2018-01-01 open Assets:Something:Cash\n'
          '2018-01-01 open Income:Donations\n'
          '2018-02-16 * "Do something"\n'
          '  Income:Donations\n'
          '  Assets:Something:Cash    1.00 USD\n'
          '2019-01-01 close Assets:Something:Cash\n',
        ),
      ),
      isEmpty,
    );
  });

  test('inserts a zero balance per currency seen in postings', () {
    expect(
      balances(
        booked(
          'plugin "beancount.plugins.check_drained"\n'
          '2018-01-01 open Assets:Something:Cash\n'
          '2018-01-01 open Income:Donations\n'
          '2018-02-16 * "Do something"\n'
          '  Income:Donations       -1.00 USD\n'
          '  Assets:Something:Cash   1.00 USD\n'
          '2018-02-17 * "Do something in another currency"\n'
          '  Income:Donations       -1.00 CAD\n'
          '  Assets:Something:Cash   1.00 CAD\n'
          '2018-12-31 * "Drain"\n'
          '  Income:Donations        1.00 USD\n'
          '  Assets:Something:Cash  -1.00 USD\n'
          '2018-12-31 * "Drain CAD"\n'
          '  Income:Donations        1.00 CAD\n'
          '  Assets:Something:Cash  -1.00 CAD\n'
          '2019-01-01 close Assets:Something:Cash\n',
        ),
      ),
      ['2019-01-02 Assets:Something:Cash 0 USD', '2019-01-02 Assets:Something:Cash 0 CAD'],
    );
  });

  test('inserts a zero balance per currency declared on the open', () {
    expect(
      balances(
        booked(
          'plugin "beancount.plugins.check_drained"\n'
          '2018-01-01 open Assets:Something:Cash  USD,CAD\n'
          '2018-01-01 open Income:Donations\n'
          '2019-01-01 close Assets:Something:Cash\n',
        ),
      ),
      ['2019-01-02 Assets:Something:Cash 0 USD', '2019-01-02 Assets:Something:Cash 0 CAD'],
    );
  });

  test('skips currencies already asserted on the closing date', () {
    expect(
      balances(
        booked(
          'plugin "beancount.plugins.check_drained"\n'
          '2018-01-01 open Assets:Something:Cash  USD,CAD\n'
          '2018-01-01 open Income:Donations\n'
          '2018-02-16 * "Do something"\n'
          '  Income:Donations       -1.00 USD\n'
          '  Assets:Something:Cash   1.00 USD\n'
          '2019-01-01 balance Assets:Something:Cash   1.00 USD\n'
          '2019-01-01 close Assets:Something:Cash\n',
        ),
      ),
      ['2019-01-02 Assets:Something:Cash 0 CAD', '2019-01-01 Assets:Something:Cash 1 USD'],
    );
  });

  test('errors when a closed account still has a balance', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_drained"\n'
        '2018-01-01 open Assets:Something:Cash\n'
        '2018-01-01 open Income:Donations\n'
        '2018-02-16 * "Do something"\n'
        '  Income:Donations       -1.00 USD\n'
        '  Assets:Something:Cash   1.00 USD\n'
        '2019-01-01 close Assets:Something:Cash\n',
      ),
      anyElement(contains('Balance failed')),
    );
  });

  test('ignores income and expense accounts', () {
    expect(
      balances(
        booked(
          'plugin "beancount.plugins.check_drained"\n'
          '2018-01-01 open Income:Donations\n'
          '2018-01-01 open Expenses:Splurge\n'
          '2018-02-16 * "Do something"\n'
          '  Income:Donations    -1.00 USD\n'
          '  Expenses:Splurge     1.00 USD\n'
          '2018-03-01 close Income:Donations\n'
          '2018-03-01 close Expenses:Splurge\n',
        ),
      ),
      isEmpty,
    );
  });
}
