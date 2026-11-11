// Pad and balance stage behaviour.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('pad inserts balancing transaction before balance assertion', () {
    const String source = '''
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 pad Assets:Checking Equity:Opening-Balances
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final Ledger ledger = Book().process(const p.BeancountParser().parse(source, filename: 'pad.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final List<Directive> directives = (ledger as LedgerDirectives).directives;
    final List<TransactionBody> txns = directives.map((Directive d) => d.body).whereType<TransactionBody>().toList();
    expect(txns, hasLength(1));
    expect(txns.single.value.postings.first.units.number, Decimal.parse('100.00'));
    expect(txns.single.value.flag, Flag.letter('P'));
    expect(txns.single.value.origin, isA<SourceOrigin>());
    expect((txns.single.value.origin as SourceOrigin).location.filename, 'pad.beancount');
  });

  test('pad transactions follow insert-entry on posting accounts', () {
    const String source = '''
2020-01-01 custom "fava-option" "insert-entry" "Assets:Checking"
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 pad Assets:Checking Equity:Opening-Balances
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final Ledger ledger = Book().process(const p.BeancountParser().parse(source, filename: 'checking.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final Iterable<TransactionBody> txns = (ledger as LedgerDirectives).directives
        .map((Directive d) => d.body)
        .whereType<TransactionBody>();
    final SourceOrigin origin = txns.single.value.origin as SourceOrigin;
    expect(origin.location.filename, 'checking.beancount');
  });

  test('pad looks ahead through intervening transactions', () {
    const String source = '''
2024-01-01 open Assets:Bank
2024-01-01 open Equity:Opening-Balances
2024-01-01 open Expenses:Food
2024-01-01 pad Assets:Bank Equity:Opening-Balances
2024-01-15 * "Withdrawal"
  Assets:Bank  -200.00 USD
  Expenses:Food
2024-01-31 balance Assets:Bank 800.00 USD
''';
    final Ledger ledger = Book().process(const p.BeancountParser().parse(source, filename: 'pad-ahead.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
  });

  test('pad covers every currency asserted after it', () {
    const String source = '''
2024-01-01 open Assets:Cash
2024-01-01 open Equity:Opening-Balances
2024-01-01 pad Assets:Cash Equity:Opening-Balances
2024-01-02 balance Assets:Cash 200 CAD
2024-01-02 balance Assets:Cash 300 USD
''';
    final Ledger ledger = Book().process(
      const p.BeancountParser().parse(source, filename: 'pad-currencies.beancount'),
    );
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final List<TransactionBody> txns = (ledger as LedgerDirectives).directives
        .map((Directive d) => d.body)
        .whereType<TransactionBody>()
        .toList();
    expect(txns, hasLength(2));
    final Map<String, Decimal> padded = <String, Decimal>{
      for (final TransactionBody txn in txns)
        txn.value.postings.first.units.currency.name: txn.value.postings.first.units.number,
    };
    expect(padded, <String, Decimal>{'CAD': Decimal.parse('200'), 'USD': Decimal.parse('300')});
  });

  test('pad covers a later balance after intervening transactions', () {
    const String source = '''
2024-01-01 open Assets:Cash
2024-01-01 open Equity:Opening-Balances
2024-01-01 open Expenses:Food
2024-01-01 pad Assets:Cash Equity:Opening-Balances
2024-01-02 balance Assets:Cash 200 CAD
2024-01-10 * "Spend"
  Assets:Cash  -450.00 USD
  Expenses:Food
2024-01-31 balance Assets:Cash 30.96 USD
''';
    final Ledger ledger = Book().process(
      const p.BeancountParser().parse(source, filename: 'pad-later.beancount'),
    );
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final List<TransactionBody> txns = (ledger as LedgerDirectives).directives
        .map((Directive d) => d.body)
        .whereType<TransactionBody>()
        .where((TransactionBody txn) => txn.value.flag == Flag.letter('P'))
        .toList();
    expect(txns, hasLength(2));
    final List<Decimal> usd = <Decimal>[
      for (final TransactionBody txn in txns)
        if (txn.value.postings.first.units.currency.name == 'USD') txn.value.postings.first.units.number,
    ];
    expect(usd.single, Decimal.parse('480.96'));
  });

  test('balance assertion infers tolerance from written decimal places', () {
    const String source = '''
2024-01-01 open Assets:Bank
2024-01-01 open Equity:Opening-Balances
2024-01-15 * "Deposit"
  Assets:Bank  1000.004 USD
  Equity:Opening-Balances
2024-01-31 balance Assets:Bank 1000.00 USD
''';
    final Ledger ledger = Book().process(const p.BeancountParser().parse(source, filename: 'bal-tol.beancount'));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
  });

  test('failed balance assertion yields errors', () {
    const String source = '''
2020-01-01 open Assets:Checking
2020-01-01 open Equity:Opening-Balances
2020-01-01 * "seed"
  Assets:Checking           50.00 USD
  Equity:Opening-Balances  -50.00 USD
2020-01-02 balance Assets:Checking 100.00 USD
''';
    final Ledger ledger = Book().process(const p.BeancountParser().parse(source, filename: 'bal.beancount'));
    expect(ledger, isA<LedgerErrors>());
    final List<ProcessingError> errors = (ledger as LedgerErrors).errors;
    expect(errors.any((ProcessingError e) => e.message.contains('Balance failed')), isTrue);
  });
}
