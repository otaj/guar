// Port of beancount.plugins.currency_accounts tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

List<String> _postings(List<Directive> directives) => <String>[
  for (final Directive directive in directives)
    if (directive.body case TransactionBody(:final Transaction value))
      for (final Posting posting in value.postings) '${posting.account.name} ${posting.units}',
];

bool _processed(Directive directive) =>
    directive.meta.entries.any((MetaEntry e) => e.key == 'currency_accounts_processed');

void main() {
  test('neutralizes a currency conversion under the default base account', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.currency_accounts" ""\n'
      '2018-01-01 open Assets:Checking\n'
      '2018-01-01 open Income:Salary\n'
      '2018-03-02 * ""\n'
      '  Assets:Checking    1200.00 CAD\n'
      '  Income:Salary     -1000.00 USD @ 1.2 CAD\n',
    );
    expect(opens(directives), containsAll(<dynamic>['Equity:CurrencyAccounts:CAD', 'Equity:CurrencyAccounts:USD']));
    expect(_postings(directives), <String>[
      'Assets:Checking 1200 CAD',
      'Equity:CurrencyAccounts:CAD -1200 CAD',
      'Income:Salary -1000 USD',
      'Equity:CurrencyAccounts:USD 1000 USD',
    ]);
  });

  test('uses a valid base account from the configuration', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.currency_accounts" "Assets:TradingAccounts"\n'
      '2018-01-01 open Assets:Checking\n'
      '2018-01-01 open Income:Salary\n'
      '2018-03-02 * ""\n'
      '  Assets:Checking    1200.00 CAD\n'
      '  Income:Salary     -1000.00 USD @ 1.2 CAD\n',
    );
    expect(opens(directives), containsAll(<dynamic>['Assets:TradingAccounts:CAD', 'Assets:TradingAccounts:USD']));
  });

  test('marks only the transactions it rewrites', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.currency_accounts" ""\n'
      '2018-01-01 open Assets:Checking\n'
      '2018-01-01 open Income:Salary\n'
      '2018-03-01 * ""\n'
      '  Assets:Checking     100.00 USD\n'
      '  Income:Salary      -100.00 USD\n'
      '2018-03-02 * "" #processed\n'
      '  Assets:Checking    1200.00 CAD\n'
      '  Income:Salary     -1000.00 USD @ 1.2 CAD\n',
    );
    for (final Directive directive in directives) {
      if (directive.body case TransactionBody(:final Transaction value)) {
        expect(_processed(directive), value.tags.any((Tag tag) => tag.name == 'processed'));
      }
    }
  });

  test('leaves single-currency transactions held at cost alone', () {
    final List<Directive> directives = booked(
      'plugin "beancount.plugins.currency_accounts" ""\n'
      '2018-01-01 open Assets:Invest\n'
      '2018-01-01 open Assets:Cash\n'
      '2018-01-01 open Income:Profits\n'
      '2018-03-01 * ""\n'
      '  Assets:Invest    2 HOOL {1000.00 USD}\n'
      '  Assets:Cash     -2000.00 USD\n'
      '2018-03-02 * ""\n'
      '  Assets:Invest   -2 HOOL {1000.00 USD} @ 1010.00 USD\n'
      '  Assets:Cash      2020.00 USD\n'
      '  Income:Profits    -20.00 USD\n',
    );
    expect(opens(directives), <String>['Assets:Invest', 'Assets:Cash', 'Income:Profits']);
    expect(directives.every((Directive directive) => !_processed(directive)), isTrue);
  });
}
