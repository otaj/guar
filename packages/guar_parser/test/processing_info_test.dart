// Observed commodities and inferred display context on ProcessingInfo.

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

  List<String> commodityNames(ProcessingInfo info) => [for (final currency in info.commodities) currency.name];

  BeanNumber? quantum(DisplayContext context, String currency) {
    for (final precision in context.precisions) {
      if (precision.key case DisplayPrecisionCurrency(:final value) when value.name == currency) {
        return precision.value;
      }
    }
    return null;
  }

  test('records every observed commodity and infers display precision', () {
    const source = '''
2014-01-01 commodity EUR
2014-01-01 open Assets:Bank EUR
2014-01-02 * "Coffee"
  Assets:Cash        -4.10 USD
  Expenses:Food       4.10 USD
2014-01-03 * "Cash"
  Assets:Cash        -100 JPY
  Expenses:Food       100 JPY
2014-01-04 price HOOL 510.00 USD
''';
    final info = directives(parser.parse(source, filename: file)).info;
    expect(commodityNames(info), ['EUR', 'HOOL', 'JPY', 'USD']);
    expect(quantum(info.displayContext, 'USD'), BeanNumber(verbatim: '0.01', resolved: Decimal.parse('0.01')));
    expect(quantum(info.displayContext, 'JPY'), BeanNumber(verbatim: '1', resolved: Decimal.one));
    expect(quantum(info.displayContext, 'EUR'), isNull);
    expect(quantum(info.displayContext, 'HOOL'), isNull);
  });

  test('uses the most common fractional width, preferring the wider width on a tie', () {
    const source = '''
2014-01-01 * "Mixed"
  Assets:Cash         -1.0 USD
  Assets:Cash         -1.00 USD
  Expenses:Food        2.00 USD
''';
    final info = directives(parser.parse(source, filename: file)).info;
    expect(quantum(info.displayContext, 'USD')?.verbatim, '0.01');
  });

  test('includes currencies from costs, metadata, and custom amounts', () {
    const source = '''
2014-01-01 * "Buy"
  ticker: HOOL
  Assets:Broker    2 HOOL {500.00 USD}
    lot: 345.67 CAD
  Assets:Cash  -1000.00 USD
2014-01-02 custom "fx" 1.2345 GBP
''';
    final info = directives(parser.parse(source, filename: file)).info;
    expect(commodityNames(info), ['CAD', 'GBP', 'HOOL', 'USD']);
    expect(quantum(info.displayContext, 'USD')?.verbatim, '0.01');
    expect(quantum(info.displayContext, 'CAD')?.verbatim, '0.01');
    expect(quantum(info.displayContext, 'GBP')?.verbatim, '0.0001');
    expect(quantum(info.displayContext, 'HOOL')?.verbatim, '1');
  });

  test('splice recomputes commodities from the merged directives', () {
    final base = parser.parse('2014-01-01 * "A"\n  Assets:Cash  -1 USD\n  Expenses:Food  1 USD\n', filename: file);
    expect(commodityNames(directives(base).info), ['USD']);
    final spliced = parser.splice(
      base,
      '2014-01-02 * "B"\n  Assets:Cash  -100 JPY\n  Expenses:Food  100 JPY\n',
      filename: file,
      startLine: 4,
      endLine: 3,
    );
    expect(commodityNames(directives(spliced).info), ['JPY', 'USD']);
    expect(quantum(directives(spliced).info.displayContext, 'JPY')?.verbatim, '1');
  });
}
