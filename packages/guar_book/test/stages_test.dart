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
    expect(txns.single.value.flag, Flag.letter('P'));
    expect(txns.single.value.origin, isA<SourceOrigin>());
    expect((txns.single.value.origin as SourceOrigin).location.filename, 'pad.beancount');
  });

  test('pad transactions follow insert-entry on posting accounts', () {
    final source = '''
2020-01-01 custom "fava-option" "insert-entry" "Assets:Checking"
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 pad Assets:Checking Equity:Opening-Balances
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'checking.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final txns = (ledger as LedgerDirectives).directives.map((d) => d.body).whereType<TransactionBody>();
    final origin = txns.single.value.origin as SourceOrigin;
    expect(origin.location.filename, 'checking.beancount');
  });

  test('pad looks ahead through intervening transactions', () {
    final source = '''
2024-01-01 open Assets:Bank
2024-01-01 open Equity:Opening-Balances
2024-01-01 open Expenses:Food
2024-01-01 pad Assets:Bank Equity:Opening-Balances
2024-01-15 * "Withdrawal"
  Assets:Bank  -200.00 USD
  Expenses:Food
2024-01-31 balance Assets:Bank 800.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'pad-ahead.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
  });

  test('balance assertion infers tolerance from written decimal places', () {
    final source = '''
2024-01-01 open Assets:Bank
2024-01-01 open Equity:Opening-Balances
2024-01-15 * "Deposit"
  Assets:Bank  1000.004 USD
  Equity:Opening-Balances
2024-01-31 balance Assets:Bank 1000.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source, filename: 'bal-tol.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
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
