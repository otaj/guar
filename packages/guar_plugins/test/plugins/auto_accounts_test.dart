// Port of beancount.plugins.auto_accounts tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('auto_accounts inserts opens at first use', () {
    final ledger = booked(
      'plugin "beancount.plugins.auto_accounts"\n'
      '2014-02-01 *\n'
      '  Assets:US:Bank:Checking     100 USD\n'
      '  Assets:US:Bank:Savings     -100 USD\n'
      '\n'
      '2014-03-11 *\n'
      '  Assets:US:Bank:Checking     100 USD\n'
      '  Equity:Something           -100 USD\n',
    );
    final opens = [
      for (final d in ledger)
        if (d.body case OpenBody(:final account)) '${d.date} ${account.name}',
    ];
    expect(
      opens,
      containsAll([
        '2014-02-01 Assets:US:Bank:Checking',
        '2014-02-01 Assets:US:Bank:Savings',
        '2014-03-11 Equity:Something',
      ]),
    );
  });
}
