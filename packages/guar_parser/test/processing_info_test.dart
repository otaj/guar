// Observed commodities and inferred display context on ProcessingInfo.

import 'package:decimal/decimal.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();
  const String file = 'ledger.beancount';

  ParsedLedgerDirectives directives(ParsedLedger ledger) => switch (ledger) {
    ParsedLedgerDirectives() => ledger,
    ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
      errors.map((ParseError e) => e.message).join('\n'),
    ),
  };

  List<String> commodityNames(ProcessingInfo info) => <String>[
    for (final Currency currency in info.commodities) currency.name,
  ];

  BeanNumber? quantum(DisplayContext context, String currency) {
    for (final DisplayPrecision precision in context.precisions) {
      if (precision.key case DisplayPrecisionCurrency(:final Currency value) when value.name == currency) {
        return precision.value;
      }
    }
    return null;
  }

  test('does not record currencies from open constraints', () {
    const String source = '''
2014-01-01 open Assets:Bank USD
2014-01-01 open Assets:Cash EUR, JPY
''';
    final ProcessingInfo info = directives(parser.parse(source, filename: file)).info;
    expect(commodityNames(info), isEmpty);
  });

  test('records every observed commodity and infers display precision', () {
    const String source = '''
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
    final ProcessingInfo info = directives(parser.parse(source, filename: file)).info;
    expect(commodityNames(info), <String>['HOOL', 'JPY', 'USD']);
    expect(quantum(info.displayContext, 'USD'), BeanNumber(verbatim: '0.01', resolved: Decimal.parse('0.01')));
    expect(quantum(info.displayContext, 'JPY'), BeanNumber(verbatim: '1', resolved: Decimal.one));
    expect(quantum(info.displayContext, 'EUR'), isNull);
    expect(quantum(info.displayContext, 'HOOL'), isNull);
  });

  test('uses the most common fractional width, preferring the wider width on a tie', () {
    const String source = '''
2014-01-01 * "Mixed"
  Assets:Cash         -1.0 USD
  Assets:Cash         -1.00 USD
  Expenses:Food        2.00 USD
''';
    final ProcessingInfo info = directives(parser.parse(source, filename: file)).info;
    expect(quantum(info.displayContext, 'USD')?.verbatim, '0.01');
  });

  test('records currencies from transaction costs and balances but not metadata or custom values', () {
    const String source = '''
2014-01-01 * "Buy"
  ticker: CAD
  Assets:Broker    2 HOOL {500.00 USD}
    lot: 345.67 CAD
  Assets:Cash  -1000.00 USD
2014-01-02 custom "fx" 1.2345 GBP
2014-01-03 custom "tag" EUR
2014-01-04 balance Assets:Cash 10.00 CHF
''';
    final ProcessingInfo info = directives(parser.parse(source, filename: file)).info;
    expect(commodityNames(info), <String>['CHF', 'HOOL', 'USD']);
    expect(quantum(info.displayContext, 'USD')?.verbatim, '0.01');
    expect(quantum(info.displayContext, 'HOOL')?.verbatim, '1');
    expect(quantum(info.displayContext, 'CHF')?.verbatim, '0.01');
    expect(quantum(info.displayContext, 'CAD'), isNull);
    expect(quantum(info.displayContext, 'GBP'), isNull);
    expect(quantum(info.displayContext, 'EUR'), isNull);
  });

  test('splice recomputes commodities from the merged directives', () {
    final ParsedLedger base = parser.parse(
      '2014-01-01 * "A"\n  Assets:Cash  -1 USD\n  Expenses:Food  1 USD\n',
      filename: file,
    );
    expect(commodityNames(directives(base).info), <String>['USD']);
    final ParsedLedger spliced = parser.splice(
      base,
      '2014-01-02 * "B"\n  Assets:Cash  -100 JPY\n  Expenses:Food  100 JPY\n',
      filename: file,
      startLine: 4,
      endLine: 3,
    );
    expect(commodityNames(directives(spliced).info), <String>['JPY', 'USD']);
    expect(quantum(directives(spliced).info.displayContext, 'JPY')?.verbatim, '1');
  });
}
