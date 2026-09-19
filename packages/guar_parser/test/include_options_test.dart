// Beancount honors option and plugin only in the root file, not in includes.

import 'dart:io';

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();

  ParsedLedgerDirectives ok(ParsedLedger ledger) => switch (ledger) {
    ParsedLedgerDirectives() => ledger,
    ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
      errors.map((ParseError e) => e.message).join('\n'),
    ),
  };

  ParsedLedger parseTree({required String rootSource, required String childSource}) {
    final Directory dir = Directory.systemTemp.createTempSync('guar_include_opt_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/child.beancount').writeAsStringSync(childSource);
    final File root = File('${dir.path}/ledger.beancount')..writeAsStringSync(rootSource);
    return parser.parse(root.readAsStringSync(), filename: root.path);
  }

  test('ignores option directives from included files', () {
    final ParsedLedgerDirectives ledger = ok(
      parseTree(
        rootSource: 'option "title" "Root"\ninclude "child.beancount"\n',
        childSource: 'option "title" "Child"\noption "operating_currency" "EUR"\n2014-01-01 open Assets:Cash\n',
      ),
    );
    expect(ledger.options.title, 'Root');
    expect(ledger.options.operatingCurrency, isEmpty);
    expect(ledger.info.optionSettings, hasLength(1));
    expect(ledger.info.optionSettings.single.value, 'Root');
    expect(ledger.directives, hasLength(1));
    expect(ledger.warnings, hasLength(2));
    expect(
      ledger.warnings.every((ParseWarning warning) => warning.message == 'option ignored in included file'),
      isTrue,
    );
    expect(ledger.warnings.map((ParseWarning warning) => warning.location.linenoBegin), <int>[1, 2]);
    expect(
      ledger.warnings.map((ParseWarning warning) => warning.location.filename),
      everyElement(endsWith('child.beancount')),
    );
  });

  test('ignores plugin directives from included files', () {
    final ParsedLedgerDirectives ledger = ok(
      parseTree(
        rootSource: 'plugin "beancount.plugins.auto_accounts"\ninclude "child.beancount"\n',
        childSource: 'plugin "beancount.plugins.implicit_prices" "USD"\n2014-01-01 open Assets:Cash\n',
      ),
    );
    expect(ledger.info.plugin, hasLength(1));
    expect(ledger.info.plugin.single.name, 'beancount.plugins.auto_accounts');
    expect(ledger.directives, hasLength(1));
    expect(ledger.warnings.single.message, 'plugin ignored in included file');
    expect(ledger.warnings.single.location.linenoBegin, 1);
    expect(ledger.warnings.single.location.filename, endsWith('child.beancount'));
  });

  test('warns instead of applying a deprecated option in an included file', () {
    final ParsedLedgerDirectives ledger = ok(
      parseTree(
        rootSource: 'include "child.beancount"\n',
        childSource: 'option "insert_pythonpath" "TRUE"\n2014-01-01 open Assets:Cash\n',
      ),
    );
    expect(ledger.options.insertPythonpath, isNull);
    expect(ledger.info.optionSettings, isEmpty);
    expect(ledger.warnings.single.message, 'option ignored in included file');
  });

  test('unknown option in an included file still fails', () {
    final ParsedLedger ledger = parseTree(
      rootSource: 'include "child.beancount"\n',
      childSource: 'option "not_an_option" "x"\n',
    );
    expect(ledger, isA<ParsedLedgerErrors>());
    expect((ledger as ParsedLedgerErrors).errors.single.message, 'unknown option');
  });

  test('malformed option in an included file still fails', () {
    final ParsedLedger ledger = parseTree(rootSource: 'include "child.beancount"\n', childSource: 'option title "x"\n');
    expect(ledger, isA<ParsedLedgerErrors>());
    expect((ledger as ParsedLedgerErrors).errors.single.message, startsWith("found '"));
  });

  test('malformed plugin in an included file still fails', () {
    final ParsedLedger ledger = parseTree(
      rootSource: 'include "child.beancount"\n',
      childSource: 'plugin auto_accounts\n',
    );
    expect(ledger, isA<ParsedLedgerErrors>());
    expect((ledger as ParsedLedgerErrors).errors.single.message, startsWith("found '"));
  });
}
