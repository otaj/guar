// Incremental splice of an unparsed snippet into a booked ledger.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  const p.BeancountParser parser = p.BeancountParser();
  final Book book = Book();
  const String file = 'ledger.beancount';

  LedgerDirectives ok(Ledger ledger) => switch (ledger) {
    LedgerDirectives() => ledger,
    LedgerErrors(:final List<ProcessingError> errors) => throw TestFailure(
      errors.map((ProcessingError e) => e.message).join('\n'),
    ),
  };

  List<String> openAccounts(Ledger ledger) => <String>[
    for (final Directive directive in ok(ledger).directives)
      if (directive.body case OpenBody(:final Account account)) account.name,
  ];

  test('inserts a snippet and returns a booked ledger', () {
    final p.ParsedLedger base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final Ledger spliced = book.splice(
      base,
      '2014-01-02 open Assets:Checking\n',
      filename: file,
      startLine: 2,
      endLine: 1,
    );
    expect(openAccounts(spliced), <String>['Assets:Cash', 'Assets:Checking']);
  });

  test('replaces an overlapping directive and rebooks the result', () {
    final p.ParsedLedger base = parser.parse(
      '2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Checking\n',
      filename: file,
    );
    final Ledger spliced = book.splice(
      base,
      '2014-01-01 open Assets:Wallet\n',
      filename: file,
      startLine: 1,
      endLine: 1,
    );
    expect(openAccounts(spliced), <String>['Assets:Wallet', 'Assets:Checking']);
  });

  test('rebooks interpolated transactions after a splice', () {
    final p.ParsedLedger base = parser.parse(
      '2014-01-01 open Assets:Cash\n'
      '2014-01-01 open Expenses:Food\n'
      '2014-02-01 * "Lunch"\n'
      '  Assets:Cash  -10 USD\n'
      '  Expenses:Food\n',
      filename: file,
    );
    final Ledger spliced = book.splice(
      base,
      '2014-02-01 * "Dinner"\n'
      '  Assets:Cash  -25 USD\n'
      '  Expenses:Food\n',
      filename: file,
      startLine: 3,
      endLine: 5,
    );
    final Directive txn = ok(spliced).directives.where((Directive d) => d.body is TransactionBody).single;
    final Transaction body = (txn.body as TransactionBody).value;
    expect(body.narration, 'Dinner');
    expect(body.postings.map((Posting posting) => posting.units.number.toString()).toList(), <String>['-25', '25']);
  });

  test('returns processing errors when the spliced snippet fails to parse', () {
    final p.ParsedLedger base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final Ledger spliced = book.splice(base, 'not a directive\n', filename: file, startLine: 2, endLine: 1);
    expect(spliced, isA<LedgerErrors>());
  });
}
