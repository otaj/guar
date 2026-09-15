// Diff of two booked Ledgers; source locations are ignored.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  const parser = p.BeancountParser();
  final book = Book();

  LedgerDirectives ok(Ledger ledger) {
    return switch (ledger) {
      LedgerDirectives() => ledger,
      LedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  Ledger bookSource(String source, {String filename = 'ledger.beancount'}) {
    return book.process(parser.parse(source, filename: filename));
  }

  test('identical ledgers produce an empty diff', () {
    final ledger = bookSource('2014-01-01 open Assets:Cash\n');
    expect(book.diff(ledger, ledger).isEmpty, isTrue);
  });

  test('reports a directive only in the right ledger as onlyInRight', () {
    final left = bookSource('2014-01-01 open Assets:Cash\n');
    final right = bookSource('2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Checking\n');
    final diff = book.diff(left, right);
    expect(diff.onlyInLeft, isEmpty);
    expect(diff.onlyInRight, hasLength(1));
    expect(diff.onlyInRight.single.body, isA<OpenBody>());
    expect((diff.onlyInRight.single.body as OpenBody).account.name, 'Assets:Checking');
  });

  test('same content at different locations is equal', () {
    const source = '2014-01-01 open Assets:Cash\n';
    final left = bookSource(source, filename: 'a.beancount');
    final right = bookSource(source, filename: 'b.beancount');
    expect(book.diff(left, right).isEmpty, isTrue);
  });

  test('different bodies at the same span appear as onlyInLeft and onlyInRight', () {
    final left = bookSource('2014-01-01 open Assets:Cash\n');
    final right = bookSource('2014-01-01 open Assets:Wallet\n');
    final diff = book.diff(left, right);
    expect((diff.onlyInLeft.single.body as OpenBody).account.name, 'Assets:Cash');
    expect((diff.onlyInRight.single.body as OpenBody).account.name, 'Assets:Wallet');
  });

  test('diffs option scalars after booking defaults are applied', () {
    final left = bookSource('option "title" "Old"\n2014-01-01 open Assets:Cash\n');
    final right = bookSource('option "title" "New"\n2014-01-01 open Assets:Cash\n');
    final diff = book.diff(left, right);
    expect(diff.options.title, const FieldChange<String?>(left: 'Old', right: 'New'));
    expect(ok(left).options.title, 'Old');
  });

  test('diffs processing errors and mixed success versus failure', () {
    final left = bookSource('2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Cash\n');
    final right = bookSource('2014-01-01 open Assets:Bank\n2014-01-02 open Assets:Bank\n');
    final errors = book.diff(left, right);
    expect(errors.errorsOnlyInLeft.single.message, contains('Assets:Cash'));
    expect(errors.errorsOnlyInRight.single.message, contains('Assets:Bank'));

    final success = bookSource('2014-01-01 open Assets:Cash\n');
    final mixed = book.diff(success, left);
    expect(mixed.onlyInLeft, hasLength(1));
    expect(mixed.errorsOnlyInRight, isNotEmpty);
    expect(mixed.onlyInRight, isEmpty);
  });
}
