// Port of beancount.plugins.auto_accounts tests.

import 'dart:io';

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('auto_accounts inserts opens at first use', () {
    final List<Directive> ledger = booked(
      'plugin "beancount.plugins.auto_accounts"\n'
      '2014-02-01 *\n'
      '  Assets:US:Bank:Checking     100 USD\n'
      '  Assets:US:Bank:Savings     -100 USD\n'
      '\n'
      '2014-03-11 *\n'
      '  Assets:US:Bank:Checking     100 USD\n'
      '  Equity:Something           -100 USD\n',
    );
    final List<String> opens = <String>[
      for (final Directive d in ledger)
        if (d.body case OpenBody(:final Account account)) '${d.date} ${account.name}',
    ];
    expect(
      opens,
      containsAll(<dynamic>[
        '2014-02-01 Assets:US:Bank:Checking',
        '2014-02-01 Assets:US:Bank:Savings',
        '2014-03-11 Equity:Something',
      ]),
    );
  });

  test('auto_accounts opens follow insert-entry routing', () {
    final Directory dir = Directory.systemTemp.createTempSync('guar_auto_accounts_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(
      '${dir.path}/expenses.beancount',
    ).writeAsStringSync('2010-01-01 custom "fava-option" "insert-entry" "Expenses"\n');
    File('${dir.path}/ledger.beancount').writeAsStringSync('''
plugin "beancount.plugins.auto_accounts"
include "expenses.beancount"
2014-02-01 *
  Expenses:Food     100 USD
  Assets:Cash      -100 USD
''');
    final String source = File('${dir.path}/ledger.beancount').readAsStringSync();
    final Ledger ledger = process(source, filename: '${dir.path}/ledger.beancount');
    final List<Directive> directives = switch (ledger) {
      LedgerDirectives(:final List<Directive> directives) => directives,
      LedgerErrors(:final List<ProcessingError> errors) => throw TestFailure(
        errors.map((ProcessingError e) => e.message).join('\n'),
      ),
    };
    String? filename(Directive directive) => switch (directive.origin) {
      SourceOrigin(:final BeanLocation location) => location.filename,
      GeneratedOrigin() => null,
    };
    final Directive food = directives
        .where((Directive d) => d.body is OpenBody && (d.body as OpenBody).account.name == 'Expenses:Food')
        .single;
    final Directive cash = directives
        .where((Directive d) => d.body is OpenBody && (d.body as OpenBody).account.name == 'Assets:Cash')
        .single;
    expect(filename(food), File('${dir.path}/expenses.beancount').absolute.path);
    expect(filename(cash), File('${dir.path}/ledger.beancount').absolute.path);
  });
}
