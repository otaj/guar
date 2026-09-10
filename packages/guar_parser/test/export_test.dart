// Export of a ParsedLedger to Beancount text and dart:io files.

import 'dart:io';

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = BeancountParser();

  ParsedLedgerDirectives directives(ParsedLedger ledger) {
    return switch (ledger) {
      ParsedLedgerDirectives() => ledger,
      ParsedLedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  test('drops comments and keeps the following directive on its original line', () {
    final ledger = parser.parse('; Hi\n2015-06-07 open Assets:Cash\n', filename: 'ledger.beancount');
    final exported = parser.export(ledger);
    expect(exported.split('\n')[0], isEmpty);
    expect(exported.split('\n')[1], '2015-06-07 open Assets:Cash');
    expect(directives(parser.parse(exported, filename: 'ledger.beancount')).directives.single.location.linenoBegin, 2);
  });

  test('writes options, plugins, and transactions at their source lines', () {
    final source = [
      'option "title" "Exported"',
      '',
      'plugin "beancount.plugin.unrealized"',
      '2014-01-01 open Assets:Cash USD',
      '2014-01-02 * "Shop"',
      '  Assets:Cash  -1 USD',
      '  Expenses:Food  1 USD',
      '',
    ].join('\n');
    final exported = parser.export(parser.parse(source, filename: 'ledger.beancount'));
    final lines = exported.split('\n');
    expect(lines[0], 'option "title" "Exported"');
    expect(lines[2], 'plugin "beancount.plugin.unrealized"');
    expect(lines[3], '2014-01-01 open Assets:Cash USD');
    expect(lines[4], startsWith('2014-01-02 * "Shop"'));
    expect(lines[5], contains('Assets:Cash'));
    expect(lines[6], contains('Expenses:Food'));
  });

  test('appends included-file directives after the main file', () {
    const file = 'test/cases/ParserInclude.IncludeRelative.beancount';
    final source = File(file).readAsStringSync();
    final ledger = parser.parse(source, filename: file);
    final exported = parser.export(ledger);
    final lines = exported.split('\n');
    expect(lines[2], contains('"QUITE OLD"'));
    expect(exported.indexOf('QUITE OLD'), lessThan(exported.indexOf('UNION MARKET')));
    expect(exported.indexOf('UNION MARKET'), lessThan(exported.indexOf('ANOTHER MARKET')));
    expect(exported.contains('include '), isFalse);
    final roundTrip = directives(parser.parse(exported, filename: 'exported.beancount'));
    expect(roundTrip.directives.where((d) => d.body is TransactionBody), hasLength(3));
  });

  test('exportToFile writes via dart:io and refuses a non-empty file without overwrite', () {
    final dir = Directory.systemTemp.createTempSync('guar_export_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dest = File('${dir.path}/out.beancount');
    final ledger = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');

    parser.exportToFile(ledger, dest, overwrite: false);
    expect(dest.readAsStringSync(), contains('open Assets:Cash'));

    dest.writeAsStringSync('existing content\n');
    expect(() => parser.exportToFile(ledger, dest, overwrite: false), throwsA(isA<StateError>()));

    parser.exportToFile(ledger, dest, overwrite: true);
    expect(dest.readAsStringSync(), contains('open Assets:Cash'));
    expect(dest.readAsStringSync().contains('existing content'), isFalse);
  });

  test('refuses to export a failed parse', () {
    final ledger = parser.parse('not a directive\n', filename: 'ledger.beancount');
    expect(() => parser.export(ledger), throwsStateError);
  });
}
