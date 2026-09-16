// Parsed LedgerOptions keep inferred and ordinary tolerance multipliers apart.

import 'package:decimal/decimal.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = BeancountParser();
  const file = 'ledger.beancount';

  ParsedLedgerDirectives directives(ParsedLedger ledger) {
    return switch (ledger) {
      ParsedLedgerDirectives() => ledger,
      ParsedLedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  test('inferred_tolerance_multiplier does not set tolerance_multiplier', () {
    final options = directives(parser.parse('option "inferred_tolerance_multiplier" "1.1"\n', filename: file)).options;
    expect(options.inferredToleranceMultiplier, BeanNumber(verbatim: '1.1', resolved: Decimal.parse('1.1')));
    expect(options.toleranceMultiplier, isNull);
  });

  test('tolerance_multiplier does not set inferred_tolerance_multiplier', () {
    final options = directives(parser.parse('option "tolerance_multiplier" "0.75"\n', filename: file)).options;
    expect(options.toleranceMultiplier, BeanNumber(verbatim: '0.75', resolved: Decimal.parse('0.75')));
    expect(options.inferredToleranceMultiplier, isNull);
  });

  test('both tolerance multipliers can be set independently', () {
    const source = '''
option "tolerance_multiplier" "2.0"
option "inferred_tolerance_multiplier" "0.25"
''';
    final options = directives(parser.parse(source, filename: file)).options;
    expect(options.toleranceMultiplier, BeanNumber(verbatim: '2.0', resolved: Decimal.parse('2.0')));
    expect(options.inferredToleranceMultiplier, BeanNumber(verbatim: '0.25', resolved: Decimal.parse('0.25')));
  });
}
