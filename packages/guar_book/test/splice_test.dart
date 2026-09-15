// Incremental splice of an unparsed snippet into a booked ledger.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  const parser = p.BeancountParser();
  const book = Book();
  const file = 'ledger.beancount';

  LedgerDirectives ok(Ledger ledger) {
    return switch (ledger) {
      LedgerDirectives() => ledger,
      LedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  List<String> openAccounts(Ledger ledger) {
    return [
      for (final directive in ok(ledger).directives)
        if (directive.body case OpenBody(:final account)) account.name,
    ];
  }

  test('inserts a snippet and returns a booked ledger', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = book.splice(base, '2014-01-02 open Assets:Checking\n', filename: file, startLine: 2, endLine: 1);
    expect(openAccounts(spliced), ['Assets:Cash', 'Assets:Checking']);
  });

  test('replaces an overlapping directive and rebooks the result', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Checking\n', filename: file);
    final spliced = book.splice(base, '2014-01-01 open Assets:Wallet\n', filename: file, startLine: 1, endLine: 1);
    expect(openAccounts(spliced), ['Assets:Wallet', 'Assets:Checking']);
  });

  test('rebooks interpolated transactions after a splice', () {
    final base = parser.parse(
      '2014-01-01 open Assets:Cash\n'
      '2014-01-01 open Expenses:Food\n'
      '2014-02-01 * "Lunch"\n'
      '  Assets:Cash  -10 USD\n'
      '  Expenses:Food\n',
      filename: file,
    );
    final spliced = book.splice(
      base,
      '2014-02-01 * "Dinner"\n'
      '  Assets:Cash  -25 USD\n'
      '  Expenses:Food\n',
      filename: file,
      startLine: 3,
      endLine: 5,
    );
    final txn = ok(spliced).directives.where((d) => d.body is TransactionBody).single;
    final body = (txn.body as TransactionBody).value;
    expect(body.narration, 'Dinner');
    expect(body.postings.map((Posting posting) => posting.units.number.toString()).toList(), ['-25', '25']);
  });

  test('returns processing errors when the spliced snippet fails to parse', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = book.splice(base, 'not a directive\n', filename: file, startLine: 2, endLine: 1);
    expect(spliced, isA<LedgerErrors>());
  });
}
