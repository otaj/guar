// Pad and balance stage behaviour.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('pad inserts balancing transaction before balance assertion', () {
    final source = '''
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 pad Assets:Checking Equity:Opening-Balances
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'pad.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final directives = (ledger as LedgerDirectives).directives;
    final txns = directives.map((d) => d.body).whereType<TransactionBody>().toList();
    expect(txns, hasLength(1));
    expect(txns.single.value.postings.first.units.number, Decimal.parse('100.00'));
    expect(txns.single.value.origin, const Origin.generated());
  });

  test('failed balance assertion yields errors', () {
    final source = '''
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 * "seed"
  Assets:Checking           50.00 USD
  Equity:Opening-Balances  -50.00 USD
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'bal.beancount'));
    expect(ledger, isA<LedgerErrors>());
    final errors = (ledger as LedgerErrors).errors;
    expect(errors.any((e) => e.message.contains('Balance failed')), isTrue);
  });
}
