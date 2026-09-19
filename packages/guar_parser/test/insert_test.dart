// In-memory insert of directives, options, and plugins into a ParsedLedger.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = BeancountParser();
  const root = 'ledger.beancount';
  const expenses = 'expenses.beancount';
  const other = 'other.beancount';

  ParsedLedgerDirectives ok(ParsedLedger ledger) {
    return switch (ledger) {
      ParsedLedgerDirectives() => ledger,
      ParsedLedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  ParsedLedger base() {
    return parser.parse('2014-01-01 open Assets:Cash\n2014-01-01 open Expenses:Food\n', filename: root);
  }

  ParsedLedger withRule() {
    return parser.splice(
      base(),
      '2020-01-01 custom "fava-option" "insert-entry" "Expenses"\n',
      filename: expenses,
      startLine: 1,
      endLine: 0,
    );
  }

  ParsedLedger withRules() {
    return parser.splice(
      withRule(),
      '2020-01-01 custom "fava-option" "insert-entry" "Assets"\n',
      filename: other,
      startLine: 1,
      endLine: 0,
    );
  }

  ParsedDirective open(String account, {int year = 2024, int month = 6, int day = 1}) {
    return ParsedDirective(
      location: BeanLocation(linenoBegin: 1, linenoEnd: 1),
      date: BeanDate(year: year, month: month, day: day),
      body: DirectiveBody.open(account: Account(name: account)),
    );
  }

  ParsedDirective txn(List<String> accounts, {int year = 2024, int month = 6, int day = 1}) {
    return ParsedDirective(
      location: BeanLocation(linenoBegin: 1, linenoEnd: 1 + accounts.length),
      date: BeanDate(year: year, month: month, day: day),
      body: DirectiveBody.transaction(
        ParsedTransaction(
          flag: const Flag.special(SpecialFlag.asterisk),
          postings: [
            for (var i = 0; i < accounts.length; i++)
              ParsedPosting(
                location: BeanLocation(linenoBegin: 2 + i, linenoEnd: 2 + i),
                account: Account(name: accounts[i]),
              ),
          ],
        ),
      ),
    );
  }

  test('inserts an unrouted open at the end of the root file', () {
    final inserted = ok(parser.insert(base(), open('Assets:Wallet')));
    expect(inserted.directives.last.body, isA<OpenBody>());
    expect(inserted.directives.last.location.filename, root);
    expect(inserted.directives.last.location.linenoBegin, 3);
  });

  test('routes an open to the matching insert-entry file and shifts that rule', () {
    final ledger = withRule();
    final ruleLine = ok(ledger).directives.where((d) => d.body is CustomBody).single.location.linenoBegin;
    final inserted = ok(parser.insert(ledger, open('Expenses:Books')));
    final added = inserted.directives
        .where((d) => d.body is OpenBody && (d.body as OpenBody).account.name == 'Expenses:Books')
        .single;
    expect(added.location.filename, expenses);
    expect(added.location.linenoBegin, ruleLine);
    final rule = inserted.directives.where((d) => d.body is CustomBody).single;
    expect(rule.location.filename, expenses);
    expect(rule.location.linenoBegin, ruleLine + 1);
  });

  test('transactions are routed by the last posting first', () {
    final inserted = ok(parser.insert(withRules(), txn(['Expenses:Food', 'Assets:Cash'])));
    expect(inserted.directives.where((d) => d.body is TransactionBody).single.location.filename, other);
    final reversed = ok(parser.insert(withRules(), txn(['Assets:Cash', 'Expenses:Food'])));
    expect(reversed.directives.where((d) => d.body is TransactionBody).single.location.filename, expenses);
  });

  test('commodity falls back to default-file when that file is in the tree', () {
    final ledger = parser.splice(
      parser.splice(base(), '2014-01-01 commodity EUR\n', filename: other, startLine: 1, endLine: 0),
      '2020-01-01 custom "fava-option" "default-file" "other.beancount"\n',
      filename: root,
      startLine: 3,
      endLine: 2,
    );
    final inserted = ok(
      parser.insert(
        ledger,
        ParsedDirective(
          location: BeanLocation(linenoBegin: 1, linenoEnd: 1),
          date: BeanDate(year: 2024, month: 1, day: 1),
          body: DirectiveBody.commodity(currency: Currency(name: 'JPY')),
        ),
      ),
    );
    expect(
      inserted.directives
          .where((d) => d.body is CommodityBody && (d.body as CommodityBody).currency.name == 'JPY')
          .single
          .location
          .filename,
      other,
    );
  });

  ParsedLedger withDefaultFile() {
    return parser.splice(
      withRules(),
      '2020-01-01 custom "fava-option" "default-file" "other.beancount"\n',
      filename: root,
      startLine: 3,
      endLine: 2,
    );
  }

  test('inserts options at the top of the root even when other files have insert-entry rules', () {
    final inserted = ok(parser.insertOption(withRule(), 'title', 'Books'));
    expect(inserted.options.title, 'Books');
    expect(inserted.info.optionSettings.last.location.filename, root);
    expect(inserted.info.optionSettings.last.location.linenoBegin, 1);
    expect(inserted.directives.first.location.filename, root);
    expect(inserted.directives.first.location.linenoBegin, 2);
  });

  test('never places a new option in an included file', () {
    final inserted = ok(parser.insertOption(withDefaultFile(), 'title', 'Books'));
    expect(inserted.info.optionSettings, isNotEmpty);
    expect(inserted.info.optionSettings.every((setting) => setting.location.filename == root), isTrue);
  });

  test('inserts plugins at the top of the root', () {
    final inserted = ok(parser.insertPlugin(withRule(), 'beancount.plugins.auto_accounts'));
    expect(inserted.info.plugin.single.location.filename, root);
    expect(inserted.info.plugin.single.location.linenoBegin, 1);
    expect(inserted.info.plugin.single.name, 'beancount.plugins.auto_accounts');
  });

  test('never places a new plugin in an included file', () {
    final inserted = ok(parser.insertPlugin(withDefaultFile(), 'beancount.plugins.auto_accounts'));
    expect(inserted.info.plugin, isNotEmpty);
    expect(inserted.info.plugin.every((plugin) => plugin.location.filename == root), isTrue);
  });

  test('invalid option insert yields errors', () {
    final inserted = parser.insertOption(base(), 'not_an_option', 'x');
    expect(inserted, isA<ParsedLedgerErrors>());
    expect((inserted as ParsedLedgerErrors).errors.single.message, 'unknown option');
    expect(inserted.errors.single.location.filename, root);
  });
}
