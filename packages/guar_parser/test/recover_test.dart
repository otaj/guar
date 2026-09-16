// Recovering parse keeps collected directives beside errors.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = BeancountParser();
  const file = 'ledger.beancount';
  const source = '''
2024-01-01 open Assets:Bank USD
this is not a directive
2024-01-02 open Assets:Cash USD
''';

  test('default parse drops directives when any error occurs', () {
    final ledger = parser.parse(source, filename: file);
    expect(ledger, isA<ParsedLedgerErrors>());
    expect((ledger as ParsedLedgerErrors).errors, isNotEmpty);
  });

  test('recovering parse keeps later directives and the error', () {
    final ledger = parser.parse(source, filename: file, recover: true);
    expect(ledger, isA<ParsedLedgerDirectives>());
    final recovered = ledger as ParsedLedgerDirectives;
    expect(recovered.directives.map((directive) => (directive.body as OpenBody).account.name), [
      'Assets:Bank',
      'Assets:Cash',
    ]);
    expect(recovered.errors, isNotEmpty);
  });
}
