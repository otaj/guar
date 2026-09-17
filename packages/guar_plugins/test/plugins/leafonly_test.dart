// Port of beancount.plugins.leafonly tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags a posting on an account that has children', () {
    expect(
      messages(
        'plugin "beancount.plugins.leafonly"\n'
        '2011-01-01 open Expenses:Food\n'
        '2011-01-01 open Expenses:Food:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Food:Restaurant   1.00 USD\n'
        '  Assets:Other              -1.00 USD\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Food         1.00 USD\n'
        '  Assets:Other         -1.00 USD\n',
      ),
      ["Non-leaf account 'Expenses:Food' has postings on it"],
    );
  });

  test('reports the parent even when it was never opened', () {
    expect(
      messages(
        'plugin "beancount.plugins.leafonly"\n'
        '2011-01-01 open Expenses:Food:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Food         1.00 USD\n'
        '  Assets:Other         -1.00 USD\n',
      ),
      contains("Non-leaf account 'Expenses:Food' has postings on it"),
    );
  });

  test('allows a balance assertion on a non-leaf account', () {
    expect(
      messages(
        'plugin "beancount.plugins.leafonly"\n'
        '2011-01-01 open Expenses:Food\n'
        '2011-01-01 open Expenses:Food:Restaurant\n'
        '2011-01-01 open Assets:Other\n'
        '2011-05-17 * "Something"\n'
        '  Expenses:Food:Restaurant   1.00 USD\n'
        '  Assets:Other              -1.00 USD\n'
        '2011-05-18 balance Expenses:Food 1.00 USD\n',
      ),
      isEmpty,
    );
  });
}
