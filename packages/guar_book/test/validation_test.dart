// Ports of beancount ops.validation_test cases.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('duplicate open yields error', () {
    final source = '''
2014-02-11 open Assets:US:Bank:Checking2
2014-02-11 open Assets:US:Bank:Checking2
''';
    final ledger = Book().process(p.BeancountParser().parse(source));
    expect(ledger, isA<LedgerErrors>());
    expect((ledger as LedgerErrors).errors.any((e) => e.message.contains('Duplicate open')), isTrue);
  });

  test('each currency can have one elided posting', () {
    final source = '''
2024-01-01 open Assets:Bank
2024-01-01 open Expenses:Food
2024-01-15 * "Dinner"
  Expenses:Food  50.00 USD
  Expenses:Food  30.00 EUR
  Assets:Bank   -50.00 USD
  Assets:Bank
''';
    final ledger = Book().process(p.BeancountParser().parse(source));
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final txn = (ledger as LedgerDirectives).directives.last.body as TransactionBody;
    final bank = txn.value.postings.where((posting) => posting.account.name == 'Assets:Bank').last;
    expect(bank.units.number, Decimal.parse('-30.00'));
    expect(bank.units.currency.name, 'EUR');
  });

  test('unbalanced transaction yields error', () {
    final source = '''
2020-01-01 open Assets:Cash
2020-01-01 open Expenses:Food
2020-02-01 * "oops"
  Expenses:Food   10.00 USD
  Assets:Cash    -9.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source));
    expect(ledger, isA<LedgerErrors>());
    expect((ledger as LedgerErrors).errors.any((e) => e.message.contains('does not balance')), isTrue);
  });

  test('account_rounding absorbs residual within tolerance', () {
    final source = '''
option "account_rounding" "Rounding"
2020-01-01 open Assets:Cash
2020-01-01 open Expenses:Food
2020-01-01 open Equity:Rounding
2020-02-01 * "oops"
  Expenses:Food   10.00 USD
  Assets:Cash     -9.995 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source));
    expect(ledger, isA<LedgerDirectives>());
    final txn = (ledger as LedgerDirectives).directives.last.body as TransactionBody;
    expect(txn.value.postings.map((posting) => posting.account.name), contains('Equity:Rounding'));
  });

  test('unknown account reference yields error', () {
    final source = '''
2020-01-01 open Assets:Cash
2020-02-01 * "oops"
  Expenses:Food   10.00 USD
  Assets:Cash    -10.00 USD
''';
    final ledger = Book().process(p.BeancountParser().parse(source));
    expect(ledger, isA<LedgerErrors>());
    expect((ledger as LedgerErrors).errors.any((e) => e.message.contains('unknown account')), isTrue);
  });
}
