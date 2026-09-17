// Port of beancount_reds_plugins.daf.daf_mirror tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const _plugin = 'plugin "beancount_reds_plugins.daf.daf_mirror" "Assets:DAF:Brokerage-DAF"\n';

void main() {
  test('mirrors transactions for a matching asset prefix', () {
    final directives = booked(
      '$_plugin'
      '2020-01-01 open Assets:DAF:Brokerage-DAF:VTI\n'
      '2020-01-01 open Assets:DAF:Brokerage-DAF:USD\n'
      '2020-01-01 open Liabilities:DAF:Brokerage-DAF:VTI\n'
      '2020-01-01 open Liabilities:DAF:Brokerage-DAF:USD\n'
      '2020-01-01 open Income:Investments:Tax-Free:Capital-Gains:DAF:Brokerage-DAF:VTI\n'
      '\n'
      '2020-01-15 * "Sell" "xxx"\n'
      '  Assets:DAF:Brokerage-DAF:VTI                           -20 VTI {20.00 USD}\n'
      '  Income:Investments:Tax-Free:Capital-Gains:DAF:Brokerage-DAF:VTI   0 USD\n'
      '  Assets:DAF:Brokerage-DAF:USD                            400 USD\n',
    );
    final txns = [
      for (final directive in directives)
        if (directive.body case TransactionBody(:final value)) (directive, value),
    ];
    expect(txns, hasLength(2));
    expect(txns[0].$2.payee, 'Sell');
    expect(txns[1].$2.payee, 'Mirror Sell');
    expect(
      [
        for (final entry in txns[1].$1.meta.entries)
          if (entry.key == 'daf_mirror_generated') entry.value,
      ],
      [const MetaValue.boolean(true)],
    );
    expect(txns[1].$2.postings.map((p) => p.account.name).toList(), [
      'Liabilities:DAF:Brokerage-DAF:VTI',
      'Income:Investments:Tax-Free:Capital-Gains:DAF:Brokerage-DAF:VTI',
      'Liabilities:DAF:Brokerage-DAF:USD',
    ]);
    expect(txns[1].$2.postings[0].units.number, -txns[0].$2.postings[0].units.number);
  });

  test('skips transactions with other asset accounts', () {
    final txns = [
      for (final directive in booked(
        '$_plugin'
        '2020-01-01 open Assets:DAF:Brokerage-DAF:VTI\n'
        '2020-01-01 open Assets:DAF:Brokerage-DAF:USD\n'
        '2020-01-01 open Assets:Brokerage:Cash\n'
        '2020-01-01 open Income:Investments:Tax-Free:Capital-Gains:DAF:Brokerage-DAF:VTI\n'
        '\n'
        '2020-01-15 * "Sell" "xxx"\n'
        '  Assets:DAF:Brokerage-DAF:VTI                           -20 VTI {20.00 USD}\n'
        '  Income:Investments:Tax-Free:Capital-Gains:DAF:Brokerage-DAF:VTI  -1.00 USD\n'
        '  Assets:DAF:Brokerage-DAF:USD                            400 USD\n'
        '  Assets:Brokerage:Cash                                     1.00 USD\n',
      ))
        if (directive.body case TransactionBody(:final value)) value,
    ];
    expect(txns, hasLength(1));
    expect(txns.single.payee, 'Sell');
  });
}
