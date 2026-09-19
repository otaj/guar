// Non-fatal parse warnings for deprecated and unsupported options.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();
  const String file = 'ledger.beancount';

  ParsedLedgerDirectives ok(ParsedLedger ledger) => switch (ledger) {
    ParsedLedgerDirectives() => ledger,
    ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
      errors.map((ParseError e) => e.message).join('\n'),
    ),
  };

  test('deprecated allow_pipe_separator warns without failing the parse', () {
    final ParsedLedgerDirectives ledger = ok(parser.parse('option "allow_pipe_separator" "TRUE"\n', filename: file));
    expect(ledger.options.allowPipeSeparator, isTrue);
    expect(ledger.warnings, hasLength(1));
    expect(ledger.warnings.single.message, 'Allowing pipe separator temporarily; this will go away eventually.');
    expect(ledger.warnings.single.location.linenoBegin, 1);
  });

  test('deprecated allow_deprecated_none_for_tags_and_links warns', () {
    final ParsedLedgerDirectives ledger = ok(
      parser.parse('option "allow_deprecated_none_for_tags_and_links" "TRUE"\n', filename: file),
    );
    expect(ledger.options.allowDeprecatedNoneForTagsAndLinks, isTrue);
    expect(ledger.warnings.single.message, 'Allowing None for tags and link will go away eventually.');
  });

  test('deprecated inferred_tolerance_multiplier warns', () {
    final ParsedLedgerDirectives ledger = ok(
      parser.parse('option "inferred_tolerance_multiplier" "1.1"\n', filename: file),
    );
    expect(ledger.options.inferredToleranceMultiplier, isNotNull);
    expect(ledger.warnings.single.message, "Renamed to 'tolerance_multiplier'.");
  });

  test('unsupported insert_pythonpath warns and still records the option', () {
    final ParsedLedgerDirectives ledger = ok(parser.parse('option "insert_pythonpath" "TRUE"\n', filename: file));
    expect(ledger.options.insertPythonpath, isTrue);
    expect(ledger.warnings.single.message, "Option 'insert_pythonpath' is not supported.");
  });

  test('ordinary options do not emit warnings', () {
    final ParsedLedgerDirectives ledger = ok(
      parser.parse('option "title" "Books"\noption "operating_currency" "USD"\n', filename: file),
    );
    expect(ledger.warnings, isEmpty);
  });

  test('warnings survive a later fatal error', () {
    const String source = '''
option "insert_pythonpath" "TRUE"
this is not a directive
''';
    final ParsedLedger ledger = parser.parse(source, filename: file);
    expect(ledger, isA<ParsedLedgerErrors>());
    expect((ledger as ParsedLedgerErrors).warnings.single.message, "Option 'insert_pythonpath' is not supported.");
    expect(ledger.errors, isNotEmpty);
  });

  test('splice replaces a warning when the option line is rewritten', () {
    final ParsedLedger base = parser.parse(
      'option "allow_pipe_separator" "TRUE"\noption "title" "Books"\n',
      filename: file,
    );
    expect(ok(base).warnings, hasLength(1));
    final ParsedLedger spliced = parser.splice(
      base,
      'option "title" "Books"\n',
      filename: file,
      startLine: 1,
      endLine: 1,
    );
    expect(ok(spliced).warnings, isEmpty);
    expect(ok(spliced).options.allowPipeSeparator, isNull);
  });

  test('diff reports warning-only differences', () {
    final ParsedLedger left = parser.parse('option "title" "Books"\n', filename: file);
    final ParsedLedger right = parser.parse('option "insert_pythonpath" "TRUE"\n', filename: file);
    final LedgerDiff diff = parser.diff(left, right, considerLocations: false);
    expect(diff.warningsOnlyInLeft, isEmpty);
    expect(diff.warningsOnlyInRight.single.message, "Option 'insert_pythonpath' is not supported.");
  });
}
