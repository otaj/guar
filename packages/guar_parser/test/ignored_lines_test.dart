// Lines beancount's lexer ignores (org-mode headers) produce neither directives nor errors.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  test('lines starting with #, : or * are ignored', () {
    const String source = '''
#+STARTUP: showall
:LOGBOOK:
* Options
2020-01-01 open Assets:Cash
''';
    final ParsedLedger ledger = const BeancountParser().parse(source, filename: 'ignored.beancount');
    expect(ledger, isA<ParsedLedgerDirectives>(), reason: ledger.toString());
    final List<ParsedDirective> directives = (ledger as ParsedLedgerDirectives).directives;
    expect(directives, hasLength(1));
    expect(
      (directives.single.body as OpenBody).account.name,
      'Assets:Cash',
    );
  });

  test('a # line shaped like a tag is not ignored', () {
    const String source = '''
#ski-trip
2020-01-01 open Assets:Cash
''';
    final ParsedLedger ledger = const BeancountParser().parse(source, filename: 'tagline.beancount');
    expect(ledger.errors, hasLength(1));
  });
}
