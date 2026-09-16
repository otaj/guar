// Recovering book keeps directives when processing errors occur.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  const source = '''
2024-01-01 open Assets:Bank USD
2024-02-01 balance Assets:Bank 100.00 USD
''';

  test('default book drops directives when a balance fails', () {
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'bal.beancount'));
    expect(ledger, isA<LedgerErrors>());
    expect((ledger as LedgerErrors).errors, isNotEmpty);
  });

  test('recovering book keeps the failing balance and the error', () {
    final parsed = p.BeancountParser().parse(source, filename: 'bal.beancount');
    final ledger = Book().process(parsed, recover: true);
    expect(ledger, isA<LedgerDirectives>());
    final recovered = ledger as LedgerDirectives;
    expect(recovered.directives.where((directive) => directive.body is BalanceBody), hasLength(1));
    expect(recovered.errors.any((error) => error.message.contains('Balance failed')), isTrue);
  });
}
