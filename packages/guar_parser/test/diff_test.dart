// Diff of two ParsedLedgers, with a required location-sensitivity flag.

import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = BeancountParser();

  ParsedLedgerDirectives ok(ParsedLedger ledger) {
    return switch (ledger) {
      ParsedLedgerDirectives() => ledger,
      ParsedLedgerErrors(:final errors) => throw TestFailure(errors.map((e) => e.message).join('\n')),
    };
  }

  test('identical ledgers produce an empty diff', () {
    final ledger = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');
    expect(parser.diff(ledger, ledger, considerLocations: true).isEmpty, isTrue);
    expect(parser.diff(ledger, ledger, considerLocations: false).isEmpty, isTrue);
  });

  test('reports a directive only in the right ledger as onlyInRight', () {
    final left = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');
    final right = parser.parse(
      '2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Checking\n',
      filename: 'ledger.beancount',
    );
    final diff = parser.diff(left, right, considerLocations: false);
    expect(diff.onlyInLeft, isEmpty);
    expect(diff.onlyInRight, hasLength(1));
    expect(diff.onlyInRight.single.body, isA<OpenBody>());
    expect((diff.onlyInRight.single.body as OpenBody).account.name, 'Assets:Checking');
  });

  test('same content at different locations matches only when locations are ignored', () {
    const source = '2014-01-01 open Assets:Cash\n';
    final left = parser.parse(source, filename: 'a.beancount');
    final right = parser.parse(source, filename: 'b.beancount');
    expect(parser.diff(left, right, considerLocations: false).isEmpty, isTrue);
    final located = parser.diff(left, right, considerLocations: true);
    expect(located.onlyInLeft, hasLength(1));
    expect(located.onlyInRight, hasLength(1));
    expect(located.info.filename, const FieldChange<String?>(left: 'a.beancount', right: 'b.beancount'));
  });

  test('same location with different bodies is changed when locations are considered', () {
    final left = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');
    final right = parser.parse('2014-01-01 open Assets:Wallet\n', filename: 'ledger.beancount');
    final located = parser.diff(left, right, considerLocations: true);
    expect(located.onlyInLeft, isEmpty);
    expect(located.onlyInRight, isEmpty);
    expect(located.changed, hasLength(1));
    expect((located.changed.single.left.body as OpenBody).account.name, 'Assets:Cash');
    expect((located.changed.single.right.body as OpenBody).account.name, 'Assets:Wallet');
    final ignored = parser.diff(left, right, considerLocations: false);
    expect(ignored.changed, isEmpty);
    expect((ignored.onlyInLeft.single.body as OpenBody).account.name, 'Assets:Cash');
    expect((ignored.onlyInRight.single.body as OpenBody).account.name, 'Assets:Wallet');
  });

  test('diffs option scalars and list values', () {
    final left = parser.parse(
      'option "title" "Old"\noption "operating_currency" "USD"\noption "documents" "/a"\n',
      filename: 'ledger.beancount',
    );
    final right = parser.parse(
      'option "title" "New"\noption "operating_currency" "EUR"\noption "documents" "/a"\noption "documents" "/b"\n',
      filename: 'ledger.beancount',
    );
    final diff = parser.diff(left, right, considerLocations: false);
    expect(diff.options.title, const FieldChange<String?>(left: 'Old', right: 'New'));
    expect(diff.options.operatingCurrency.onlyInLeft.single.name, 'USD');
    expect(diff.options.operatingCurrency.onlyInRight.single.name, 'EUR');
    expect(diff.options.documents.onlyInLeft, isEmpty);
    expect(diff.options.documents.onlyInRight, ['/b']);
    expect(ok(left).info.optionSettings, isNotEmpty);
    expect(diff.info.optionSettings.onlyInLeft, isNotEmpty);
    expect(diff.info.optionSettings.onlyInRight, isNotEmpty);
  });

  test('plugin locations are ignored unless considerLocations is true', () {
    final left = parser.parse('plugin "beancount.plugin.unrealized"\n', filename: 'a.beancount');
    final right = parser.parse('\nplugin "beancount.plugin.unrealized"\n', filename: 'a.beancount');
    expect(parser.diff(left, right, considerLocations: false).info.plugin.isEmpty, isTrue);
    final located = parser.diff(left, right, considerLocations: true);
    expect(located.info.plugin.onlyInLeft, hasLength(1));
    expect(located.info.plugin.onlyInRight, hasLength(1));
  });

  test('diffs inferred commodities and display context', () {
    final left = parser.parse(
      '2014-01-01 * "A"\n  Assets:Cash  -1.00 USD\n  Expenses:Food  1.00 USD\n',
      filename: 'ledger.beancount',
    );
    final right = parser.parse(
      '2014-01-01 * "A"\n  Assets:Cash  -100 JPY\n  Expenses:Food  100 JPY\n',
      filename: 'ledger.beancount',
    );
    final diff = parser.diff(left, right, considerLocations: false);
    expect(diff.info.commodities.onlyInLeft.single.name, 'USD');
    expect(diff.info.commodities.onlyInRight.single.name, 'JPY');
    expect(diff.info.displayContext.onlyInLeft.single.key, DisplayPrecisionKey.currency(const Currency(name: 'USD')));
    expect(diff.info.displayContext.onlyInRight.single.key, DisplayPrecisionKey.currency(const Currency(name: 'JPY')));
  });

  test('diffs parse errors and mixed success versus failure', () {
    final left = parser.parse('not a directive\n', filename: 'ledger.beancount');
    final right = parser.parse('also bad\n', filename: 'ledger.beancount');
    final errors = parser.diff(left, right, considerLocations: false);
    expect(errors.errorsOnlyInLeft, isNotEmpty);
    expect(errors.errorsOnlyInRight, isNotEmpty);

    final success = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');
    final mixed = parser.diff(success, left, considerLocations: true);
    expect(mixed.onlyInLeft, hasLength(1));
    expect(mixed.errorsOnlyInRight, isNotEmpty);
    expect(mixed.onlyInRight, isEmpty);
  });
}
