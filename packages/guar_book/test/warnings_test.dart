// Booked ledgers forward non-fatal parse warnings.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  const p.BeancountParser parser = p.BeancountParser();
  final Book book = Book();
  const String file = 'ledger.beancount';

  LedgerDirectives ok(Ledger ledger) => switch (ledger) {
    LedgerDirectives() => ledger,
    LedgerErrors(:final List<ProcessingError> errors) => throw TestFailure(
      errors.map((ProcessingError e) => e.message).join('\n'),
    ),
  };

  test('booking forwards deprecated and unsupported option warnings', () {
    const String source = '''
option "allow_pipe_separator" "TRUE"
option "insert_pythonpath" "TRUE"
2014-01-01 open Assets:Cash
''';
    final p.ParsedLedger parsed = parser.parse(source, filename: file);
    final LedgerDirectives ledger = ok(book.process(parsed));
    expect(ledger.warnings.map((ProcessingWarning warning) => warning.message), <String>[
      'Allowing pipe separator temporarily; this will go away eventually.',
      "Option 'insert_pythonpath' is not supported.",
    ]);
    expect(ledger.warnings.every((ProcessingWarning warning) => warning.location.filename == file), isTrue);
  });

  test('failed booking still surfaces parse warnings', () {
    const String source = '''
option "allow_deprecated_none_for_tags_and_links" "TRUE"
this is not a directive
''';
    final Ledger ledger = book.process(parser.parse(source, filename: file));
    expect(ledger, isA<LedgerErrors>());
    expect(
      (ledger as LedgerErrors).warnings.single.message,
      'Allowing None for tags and link will go away eventually.',
    );
  });

  test('diff reports warning-only differences after booking', () {
    final Ledger left = book.process(parser.parse('2014-01-01 open Assets:Cash\n', filename: file));
    final Ledger right = book.process(
      parser.parse('option "inferred_tolerance_multiplier" "1.1"\n2014-01-01 open Assets:Cash\n', filename: file),
    );
    final LedgerDiff diff = book.diff(left, right);
    expect(diff.warningsOnlyInLeft, isEmpty);
    expect(diff.warningsOnlyInRight.single.message, "Renamed to 'tolerance_multiplier'.");
  });
}
