// Port of beancount_reds_plugins.capital_gains_classifier.gain_loss tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const String _header =
    'plugin "beancount_reds_plugins.capital_gains_classifier.gain_loss" '
    '"{\'Income.*:Capital-Gains.*\' : [\':Capital-Gains\', \':Capital-Gains:Gains\', \':Capital-Gains:Losses\']}"\n';

void main() {
  test('empty entries', () {
    expect(booked(_header), isEmpty);
  });

  test('classifies gains and losses', () {
    final List<Directive> directives = booked(
      '$_header'
      '2014-01-01 open Assets:Brokerage\n'
      '2014-01-01 open Assets:Bank\n'
      '2014-01-01 open Income:Capital-Gains\n'
      '\n'
      '2014-02-01 * "Buy"\n'
      '  Assets:Brokerage          200 ORNG {1 USD}\n'
      '  Assets:Bank              -200 USD\n'
      '\n'
      '2016-03-01 * "Sell"\n'
      '  Assets:Brokerage         -100 ORNG {1 USD} @ 1.50 USD\n'
      '  Assets:Bank               150 USD\n'
      '  Income:Capital-Gains\n'
      '\n'
      '2016-03-02 * "Sell"\n'
      '  Assets:Brokerage         -100 ORNG {1 USD} @ 0.50 USD\n'
      '  Assets:Bank                50 USD\n'
      '  Income:Capital-Gains\n',
    );
    expect(opens(directives), containsAll(<dynamic>['Income:Capital-Gains:Gains', 'Income:Capital-Gains:Losses']));
    final List<Transaction> sells = <Transaction>[
      for (final Directive directive in directives)
        if (directive.body case TransactionBody(:final Transaction value) when value.narration == 'Sell') value,
    ];
    expect(sells[0].postings.map((Posting p) => p.account.name), contains('Income:Capital-Gains:Gains'));
    expect(sells[1].postings.map((Posting p) => p.account.name), contains('Income:Capital-Gains:Losses'));
  });
}
