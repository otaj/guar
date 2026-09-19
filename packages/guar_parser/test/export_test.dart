// Export of a ParsedLedger to Beancount text and dart:io files.

import 'dart:io';

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();

  ParsedLedgerDirectives directives(ParsedLedger ledger) => switch (ledger) {
    ParsedLedgerDirectives() => ledger,
    ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
      errors.map((ParseError e) => e.message).join('\n'),
    ),
  };

  test('drops comments and keeps the following directive on its original line', () {
    final ParsedLedger ledger = parser.parse('; Hi\n2015-06-07 open Assets:Cash\n', filename: 'ledger.beancount');
    final String exported = parser.export(ledger);
    expect(exported.split('\n')[0], isEmpty);
    expect(exported.split('\n')[1], '2015-06-07 open Assets:Cash');
    expect(directives(parser.parse(exported, filename: 'ledger.beancount')).directives.single.location.linenoBegin, 2);
  });

  test('writes options, plugins, and transactions at their source lines', () {
    final String source = <String>[
      'option "title" "Exported"',
      '',
      'plugin "beancount.plugin.unrealized"',
      '2014-01-01 open Assets:Cash USD',
      '2014-01-02 * "Shop"',
      '  Assets:Cash  -1 USD',
      '  Expenses:Food  1 USD',
      '',
    ].join('\n');
    final String exported = parser.export(parser.parse(source, filename: 'ledger.beancount'));
    final List<String> lines = exported.split('\n');
    expect(lines[0], 'option "title" "Exported"');
    expect(lines[2], 'plugin "beancount.plugin.unrealized"');
    expect(lines[3], '2014-01-01 open Assets:Cash USD');
    expect(lines[4], startsWith('2014-01-02 * "Shop"'));
    expect(lines[5], contains('Assets:Cash'));
    expect(lines[6], contains('Expenses:Food'));
  });

  test('appends included-file directives after the main file', () {
    const String file = 'test/cases/ParserInclude.IncludeRelative.beancount';
    final String source = File(file).readAsStringSync();
    final ParsedLedger ledger = parser.parse(source, filename: file);
    final String exported = parser.export(ledger);
    final List<String> lines = exported.split('\n');
    expect(lines[2], contains('"QUITE OLD"'));
    expect(exported.indexOf('QUITE OLD'), lessThan(exported.indexOf('UNION MARKET')));
    expect(exported.indexOf('UNION MARKET'), lessThan(exported.indexOf('ANOTHER MARKET')));
    expect(exported.contains('include '), isFalse);
    final ParsedLedgerDirectives roundTrip = directives(parser.parse(exported, filename: 'exported.beancount'));
    expect(roundTrip.directives.where((ParsedDirective d) => d.body is TransactionBody), hasLength(3));
  });

  test('exportToFile writes via dart:io and refuses a non-empty file without overwrite', () {
    final Directory dir = Directory.systemTemp.createTempSync('guar_export_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File dest = File('${dir.path}/out.beancount');
    final ParsedLedger ledger = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');

    parser.exportToFile(ledger, dest, overwrite: false);
    expect(dest.readAsStringSync(), contains('open Assets:Cash'));

    dest.writeAsStringSync('existing content\n');
    expect(() => parser.exportToFile(ledger, dest, overwrite: false), throwsA(isA<StateError>()));

    parser.exportToFile(ledger, dest, overwrite: true);
    expect(dest.readAsStringSync(), contains('open Assets:Cash'));
    expect(dest.readAsStringSync().contains('existing content'), isFalse);
  });

  test('exports a bare custom currency unquoted', () {
    final String exported = parser.export(parser.parse('2014-01-01 custom "fx" EUR\n', filename: 'ledger.beancount'));
    expect(exported.trim(), '2014-01-01 custom "fx" EUR');
  });

  test('refuses to export a failed parse', () {
    final ParsedLedger ledger = parser.parse('not a directive\n', filename: 'ledger.beancount');
    expect(() => parser.export(ledger), throwsStateError);
  });
}
