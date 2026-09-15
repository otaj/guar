// Ports of beancount ops.validation_test cases.

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
