// Documents stage discovers dated files under option documents roots.

import 'dart:io';

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('documents stage inserts document directives from filesystem', () {
    final root = Directory.systemTemp.createTempSync('guar_book_docs');
    addTearDown(() => root.deleteSync(recursive: true));
    final accountDir = Directory('${root.path}/Assets/Cash')..createSync(recursive: true);
    File('${accountDir.path}/2020-03-15.receipt.pdf').writeAsStringSync('x');

    final source =
        '''
option "documents" "${root.path}"
2020-01-01 open Assets:Cash
''';
    final ledger = const Book().process(
      const p.BeancountParser().parse(source, filename: '${root.path}/ledger.beancount'),
    );
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final docs = (ledger as LedgerDirectives).directives.map((d) => d.body).whereType<DocumentBody>();
    expect(docs, isNotEmpty);
    expect(docs.first.account.name, 'Assets:Cash');
    expect(docs.first.filename.endsWith('2020-03-15.receipt.pdf'), isTrue);
  });
}
