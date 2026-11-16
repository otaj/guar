// Division by zero and escaped strings in amount expressions and quoted strings.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();
  const String file = 'ledger.beancount';

  ParsedLedgerDirectives directives(ParsedLedger ledger) => switch (ledger) {
    ParsedLedgerDirectives() => ledger,
    ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
      errors.map((ParseError e) => e.message).join('\n'),
    ),
  };

  test('division by zero fails the line instead of crashing the parse', () {
    final ParsedLedger ledger = parser.parse(
      '2024-01-01 * "x"\n  Assets:Cash  12 / 0 USD\n',
      filename: file,
      recover: true,
    );
    expect(ledger.errors, isNotEmpty);
    expect(ledger, isA<ParsedLedgerDirectives>());
    expect((ledger as ParsedLedgerDirectives).directives, isEmpty);
  });

  test('division by zero in a balance directive fails instead of crashing', () {
    final ParsedLedger ledger = parser.parse(
      '2024-01-01 balance Assets:Cash 1 / 0 USD\n',
      filename: file,
      recover: true,
    );
    expect(ledger.errors, isNotEmpty);
  });

  test('escaped quotes survive inside quoted strings', () {
    final ParsedLedgerDirectives ledger = directives(
      parser.parse(
        '2024-01-01 * "say \\"hi\\"" ""\n  Assets:Cash  1 USD\n  Assets:Bank\n',
        filename: file,
        recover: true,
      ),
    );
    final ParsedTransaction transaction = switch (ledger.directives.first.body) {
      TransactionBody(:final ParsedTransaction value) => value,
      _ => throw TestFailure('not a transaction'),
    };
    expect(transaction.payee, 'say "hi"');
  });

  test('a backslash before the closing quote does not swallow it', () {
    final ParsedLedgerDirectives ledger = directives(
      parser.parse(
        '2024-01-01 * "ends with \\" ""\n  Assets:Cash  1 USD\n  Assets:Bank\n',
        filename: file,
        recover: true,
      ),
    );
    expect(ledger, isA<ParsedLedgerDirectives>());
  });
}
