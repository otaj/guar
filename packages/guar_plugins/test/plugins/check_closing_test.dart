// Port of beancount.plugins.check_closing tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const String _source =
    'plugin "beancount.plugins.check_closing"\n'
    '2018-02-16 open Assets:US:Brokerage:Main:Cash\n'
    '2018-02-16 open Assets:US:Brokerage:Main:Options\n'
    '2018-02-16 open Expenses:Financial:Commissions\n'
    '2018-02-16 open Expenses:Financial:Fees\n'
    '2018-02-16 open Income:US:Brokerage:Main:PnL\n'
    '2018-02-16 * "SOLD -14 QQQ 100 16 FEB 18 160 CALL @5.31"\n'
    '  Assets:US:Brokerage:Main:Options     -1400 QQQ180216C160 {2.70 USD} @ 5.31 USD\n'
    '    closing: TRUE\n'
    '  Expenses:Financial:Commissions       17.45 USD\n'
    '  Expenses:Financial:Fees               0.42 USD\n'
    '  Assets:US:Brokerage:Main:Cash      7416.13 USD\n'
    '  Income:US:Brokerage:Main:PnL      -3654.00 USD\n';

void main() {
  test('inserts a zero balance the day after the closing posting', () {
    expect(balances(booked(_source)), <String>['2018-02-17 Assets:US:Brokerage:Main:Options 0 QQQ180216C160']);
  });

  test('strips the closing metadata from the posting', () {
    final List<String> keys = <String>[
      for (final Directive directive in booked(_source))
        if (directive.body case TransactionBody(:final Transaction value))
          for (final Posting posting in value.postings)
            for (final MetaEntry entry in posting.meta.entries) entry.key,
    ];
    expect(keys, isNot(contains('closing')));
  });

  test('leaves transactions without the metadata alone', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.check_closing"\n'
      '2018-02-16 open Assets:Cash\n'
      '2018-02-16 open Expenses:Food\n'
      '2018-02-16 * ""\n'
      '  Expenses:Food   10.00 USD\n'
      '  Assets:Cash    -10.00 USD\n',
    );
    expect(balances(directives), isEmpty);
  });
}
