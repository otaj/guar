// Port of beancount_reds_plugins.capital_gains_classifier.long_short tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const String _plugin =
    'plugin "beancount_reds_plugins.capital_gains_classifier.long_short" '
    '"{\'Income.*:Capital-Gains\': [\':Capital-Gains\', \':Capital-Gains:Short\', \':Capital-Gains:Long\']}"\n';

void main() {
  test('empty entries', () {
    expect(booked(_plugin), isEmpty);
  });

  test('leaves already classified sales untouched', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.auto"\n'
      '$_plugin'
      '2014-02-01 * "Buy"\n'
      '  Assets:Brokerage          100 ORNG {1 USD}\n'
      '  Assets:Bank              -100 USD\n'
      '2014-03-01 * "Sell"\n'
      '  Assets:Brokerage         -100 ORNG {1 USD} @ 1.50 USD\n'
      '  Assets:Bank               140 USD\n'
      '  Income:Capital-Gains:Short -20 USD\n'
      '  Income:Capital-Gains       -30 USD\n'
      '  Expenses:Fees              10 USD\n',
    );
    final Transaction sell = <Transaction>[
      for (final Directive directive in directives)
        if (directive.body case TransactionBody(:final Transaction value) when value.narration == 'Sell') value,
    ].single;
    expect(
      sell.postings.map((Posting p) => p.account.name),
      containsAll(<dynamic>['Income:Capital-Gains:Short', 'Income:Capital-Gains']),
    );
  });

  test('rebooks a long-term gain', () {
    expect(_gainAccount(_longSource('2016-03-01')), 'Income:Capital-Gains:Long');
  });

  test('treats one year plus a month as long-term', () {
    expect(_gainAccount(_longSource('2015-03-01')), 'Income:Capital-Gains:Long');
  });

  test('rebooks a short-term gain', () {
    expect(_gainAccount(_longSource('2014-03-01')), 'Income:Capital-Gains:Short');
  });

  test('splits mixed long and short lots', () {
    final Transaction sell = _sell(
      booked(
        '$_plugin'
        '2014-01-01 open Assets:Brokerage\n'
        '2014-01-01 open Assets:Bank\n'
        '2014-01-01 open Income:Capital-Gains\n'
        '2014-02-01 * "Buy"\n'
        '  Assets:Brokerage          100 ORNG {1 USD}\n'
        '  Assets:Bank              -100 USD\n'
        '2016-02-01 * "Buy"\n'
        '  Assets:Brokerage          100 ORNG {2 USD}\n'
        '  Assets:Bank              -200 USD\n'
        '2016-03-01 * "Sell"\n'
        '  Assets:Brokerage         -100 ORNG {1 USD} @ 2.50 USD\n'
        '  Assets:Brokerage         -100 ORNG {2 USD} @ 2.50 USD\n'
        '  Assets:Bank               500 USD\n'
        '  Income:Capital-Gains\n',
      ),
    );
    final Map<String, String> byAccount = <String, String>{
      for (final Posting posting in sell.postings) posting.account.name: posting.units.number.toString(),
    };
    expect(byAccount['Income:Capital-Gains:Short'], '-50');
    expect(byAccount['Income:Capital-Gains:Long'], '-150');
  });

  test('leap-year anniversary is still short-term', () {
    expect(
      _gainAccount(
        '$_plugin'
        '2014-01-01 open Assets:Brokerage\n'
        '2014-01-01 open Assets:Bank\n'
        '2014-01-01 open Income:Capital-Gains\n'
        '2016-02-28 * "Buy"\n'
        '  Assets:Brokerage          100 ORNG {1 USD}\n'
        '  Assets:Bank              -100 USD\n'
        '2017-02-28 * "Sell"\n'
        '  Assets:Brokerage         -100 ORNG {1 USD} @ 1.50 USD\n'
        '  Assets:Bank               150 USD\n'
        '  Income:Capital-Gains\n',
      ),
      'Income:Capital-Gains:Short',
    );
  });

  test('keeps fees on the original sale', () {
    final Transaction sell = _sell(
      booked(
        '$_plugin'
        '2014-01-01 open Assets:Brokerage\n'
        '2014-01-01 open Assets:Bank\n'
        '2014-01-01 open Expenses:Fees\n'
        '2014-01-01 open Income:Capital-Gains\n'
        '2014-02-01 * "Buy"\n'
        '  Assets:Brokerage          100 ORNG {1 USD}\n'
        '  Assets:Bank              -100 USD\n'
        '2014-03-01 * "Sell"\n'
        '  Assets:Brokerage         -100 ORNG {1 USD} @ 1.50 USD\n'
        '  Assets:Bank               140 USD\n'
        '  Income:Capital-Gains\n'
        '  Expenses:Fees              10 USD\n',
      ),
    );
    expect(
      sell.postings.map((Posting p) => p.account.name),
      containsAll(<dynamic>['Income:Capital-Gains:Short', 'Expenses:Fees']),
    );
  });

  test('classifies covering a short position', () {
    expect(
      _gainAccount(
        '$_plugin'
        '2014-01-01 open Assets:Brokerage\n'
        '2014-01-01 open Assets:Bank\n'
        '2014-01-01 open Expenses:Fees\n'
        '2014-01-01 open Income:Capital-Gains\n'
        '2014-02-01 * "Buy Short position"\n'
        '  Assets:Brokerage         -100 ORNG {1 USD}\n'
        '  Assets:Bank               100 USD\n'
        '2015-03-01 * "Sell Short position"\n'
        '  Assets:Brokerage          100 ORNG {1 USD} @ 0.50 USD\n'
        '  Assets:Bank               -50 USD\n'
        '  Income:Capital-Gains\n',
        narration: 'Sell Short position',
      ),
      'Income:Capital-Gains:Long',
    );
  });

  test('ignores reductions that omitted a price', () {
    final List<Directive> directives = booked(
      '$_plugin'
      '2014-01-01 open Assets:Brokerage\n'
      '2014-01-01 open Assets:Bank\n'
      '2014-01-01 open Income:Capital-Gains\n'
      '2014-02-01 * "Buy"\n'
      '  Assets:Brokerage          100 ORNG {1 USD}\n'
      '  Assets:Bank              -100 USD\n'
      '2016-03-01 * "Sell at complete loss"\n'
      '  Assets:Brokerage          -50 ORNG {1 USD} @ 0 USD\n'
      '  Income:Capital-Gains\n'
      '2016-03-01 * "Sell but forgot price"\n'
      '  Assets:Brokerage          -50 ORNG {1 USD}\n'
      '  Assets:Bank               100 USD\n'
      '  Income:Capital-Gains\n',
    );
    final Map<String, Transaction> named = <String, Transaction>{
      for (final Directive directive in directives)
        if (directive.body case TransactionBody(:final Transaction value)) value.narration: value,
    };
    expect(
      named['Sell at complete loss']!.postings.map((Posting p) => p.account.name),
      contains('Income:Capital-Gains:Long'),
    );
    expect(
      named['Sell but forgot price']!.postings.map((Posting p) => p.account.name),
      contains('Income:Capital-Gains'),
    );
  });
}

String _longSource(String sellDate) =>
    '$_plugin'
    '2014-01-01 open Assets:Brokerage\n'
    '2014-01-01 open Assets:Bank\n'
    '2014-01-01 open Income:Capital-Gains\n'
    '2014-02-01 * "Buy"\n'
    '  Assets:Brokerage          100 ORNG {1 USD}\n'
    '  Assets:Bank              -100 USD\n'
    '$sellDate * "Sell"\n'
    '  Assets:Brokerage         -100 ORNG {1 USD} @ 1.50 USD\n'
    '  Assets:Bank               150 USD\n'
    '  Income:Capital-Gains\n';

String _gainAccount(String source, {String narration = 'Sell'}) => _sell(
  booked(source),
  narration: narration,
).postings.firstWhere((Posting p) => p.account.name.contains('Capital-Gains')).account.name;

Transaction _sell(List<Directive> directives, {String narration = 'Sell'}) => <Transaction>[
  for (final Directive directive in directives)
    if (directive.body case TransactionBody(:final Transaction value) when value.narration == narration) value,
].single;
