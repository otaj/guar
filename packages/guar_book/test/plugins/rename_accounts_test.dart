// Port of beancount_reds_plugins.rename_accounts tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const _plugin = 'beancount_reds_plugins.rename_accounts.rename_accounts';

void main() {
  test('empty entries', () {
    expect(booked('plugin "$_plugin" "{}"\n'), isEmpty);
  });

  test('empty config leaves accounts unchanged', () {
    final names = [
      for (final posting in _postings(
        booked(
          'plugin "$_plugin" "{}"\n'
          '2014-01-01 open Assets:Account1\n'
          '2014-01-01 open Assets:Account2\n'
          '2014-01-01 open Income:Misc\n'
          '2014-01-15 *\n'
          '  Income:Misc          -1000 USD\n'
          '  Assets:Account1\n'
          '2014-01-16 *\n'
          '  Income:Misc          -1000 EUR\n'
          '  Assets:Account2\n',
        ),
      ))
        posting.account.name,
    ];
    expect(names, containsAll(['Income:Misc', 'Assets:Account1', 'Assets:Account2']));
  });

  test('single rename', () {
    final directives = booked(
      'plugin "$_plugin" "{\'Expenses:Taxes\' : \'Income:Taxes\'}"\n'
      '2014-01-01 open Assets:Account1\n'
      '2014-01-01 open Assets:Account2\n'
      '2014-01-01 open Expenses:Taxes\n'
      '2014-01-15 *\n'
      '  Assets:Account1\n'
      '  Assets:Account2        -1000 USD\n'
      '2014-01-16 *\n'
      '  Assets:Account2\n'
      '  Expenses:Taxes          1000 USD\n',
    );
    expect(opens(directives), ['Assets:Account1', 'Assets:Account2', 'Income:Taxes']);
    expect(_postings(directives).map((p) => p.account.name), isNot(contains('Expenses:Taxes')));
    expect(_postings(directives).map((p) => p.account.name), contains('Income:Taxes'));
  });

  test('renames every directive that carries an account', () {
    final directives = booked(
      'plugin "$_plugin" "{\'Assets:Account1\': \'Assets:Cash\', \'Assets:Account2\': \'Assets:AAPL\', \'Equity:Opening-Balances\': \'Equity:OpeningBalances\'}"\n'
      '2014-01-01 open Assets:Account1\n'
      '2014-01-01 open Assets:Account2\n'
      '2014-01-01 open Equity:Opening-Balances\n'
      '2014-01-14 pad Assets:Account1 Equity:Opening-Balances\n'
      '2014-01-15 balance Assets:Account1 1000 USD\n'
      '2014-01-16 * "Buy AAPL"\n'
      '  Assets:Account1        -1000 USD\n'
      '  Assets:Account2            1 AAPL {1000 USD}\n'
      '2014-01-18 note Assets:Account1 "Test note"\n'
      '2014-12-31 close Assets:Account1\n',
    );
    expect(opens(directives), ['Assets:Cash', 'Assets:AAPL', 'Equity:OpeningBalances']);
    expect(
      [
        for (final directive in directives)
          if (directive.body case PadBody(:final account, :final sourceAccount))
            '${account.name} ${sourceAccount.name}',
      ],
      ['Assets:Cash Equity:OpeningBalances'],
    );
    expect(
      [
        for (final directive in directives)
          if (directive.body case NoteBody(:final account)) account.name,
      ],
      ['Assets:Cash'],
    );
    expect(closes(directives), ['2014-12-31 Assets:Cash']);
  });

  test('regex rename with python backreferences', () {
    final directives = booked(
      'plugin "$_plugin" "{'
      r"'Income(:.+)?:Dividends(:.+)?' : 'Assets\\1:Dividends\\2', "
      r"'Expenses(:.+)?:Fees(:.+)?' : 'Assets\\1:Fees\\2'"
      '}"\n'
      '2014-01-01 open Assets:Checking USD\n'
      '2014-01-01 open Assets:Brokerage:Cash USD\n'
      '2014-01-01 open Assets:Brokerage:VTI VTI\n'
      '2014-01-01 open Income:Brokerage:Dividends:VTI USD\n'
      '2014-01-01 open Expenses:Brokerage:Fees USD\n'
      '2014-01-16 * "Dividend"\n'
      '  Income:Brokerage:Dividends:VTI    -5 USD\n'
      '  Assets:Brokerage:Cash\n'
      '2014-01-17 * "Fees"\n'
      '  Assets:Brokerage:Cash            -10 USD\n'
      '  Expenses:Brokerage:Fees\n',
    );
    expect(opens(directives), containsAll(['Assets:Brokerage:Dividends:VTI', 'Assets:Brokerage:Fees']));
    expect(_postings(directives).map((p) => p.account.name), contains('Assets:Brokerage:Dividends:VTI'));
    expect(_postings(directives).map((p) => p.account.name), contains('Assets:Brokerage:Fees'));
  });

  test('dedupes open directives renamed onto the same account', () {
    final directives = booked(
      'plugin "$_plugin" "{\'Income:Salary\': \'Income:Net-Income\', \'Income:Bonus\': \'Income:Net-Income\', \'Expenses:Tax\': \'Income:Net-Income\'}"\n'
      '2014-01-01 open Assets:Bank\n'
      '2014-01-01 open Income:Salary\n'
      '2014-01-01 open Income:Bonus\n'
      '2014-01-01 open Expenses:Tax\n'
      '2014-01-15 * "Salary"\n'
      '  Income:Salary        -5000 USD\n'
      '  Expenses:Tax          1000 USD\n'
      '  Assets:Bank\n',
    );
    expect(opens(directives).where((name) => name == 'Income:Net-Income').length, 1);
    expect(opens(directives), ['Assets:Bank', 'Income:Net-Income']);
  });
}

List<Posting> _postings(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case TransactionBody(:final value)) ...value.postings,
];
