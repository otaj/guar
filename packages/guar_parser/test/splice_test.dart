// Incremental splice of an unparsed snippet into an existing ParsedLedger.

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

  List<String> accounts(ParsedLedger ledger) {
    return [
      for (final directive in directives(ledger).directives)
        if (directive.body case OpenBody(:final account)) account.name,
    ];
  }

  test('inserts a snippet after existing directives without rereading them', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(base, '2014-01-02 open Assets:Checking\n', filename: file, startLine: 2, endLine: 1);
    expect(accounts(spliced), ['Assets:Cash', 'Assets:Checking']);
    expect(directives(spliced).directives[1].location.linenoBegin, 2);
  });

  test('replaces an overlapping directive in the same file', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Checking\n', filename: file);
    final spliced = parser.splice(base, '2014-01-01 open Assets:Wallet\n', filename: file, startLine: 1, endLine: 1);
    expect(accounts(spliced), ['Assets:Wallet', 'Assets:Checking']);
  });

  test('replaces an overlapping option and replays remaining settings', () {
    final base = parser.parse(
      'option "title" "Old"\noption "operating_currency" "USD"\n2014-01-01 open Assets:Cash\n',
      filename: file,
    );
    expect(directives(base).options.title, 'Old');
    final spliced = parser.splice(base, 'option "title" "New"\n', filename: file, startLine: 1, endLine: 1);
    final result = directives(spliced);
    expect(result.options.title, 'New');
    expect(result.options.operatingCurrency.single.name, 'USD');
    expect(accounts(spliced), ['Assets:Cash']);
  });

  test('removing an option line unsets that key', () {
    final base = parser.parse('option "title" "Named"\n2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(base, '', filename: file, startLine: 1, endLine: 1);
    expect(directives(spliced).options.title, isNull);
    expect(accounts(spliced), ['Assets:Cash']);
    expect(directives(spliced).directives.single.location.linenoBegin, 1);
  });

  test('shifts later directives when the snippet is longer than the replaced span', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n2014-01-03 open Assets:Later\n', filename: file);
    final spliced = parser.splice(
      base,
      '2014-01-01 open Assets:Cash\n2014-01-02 open Assets:Mid\n',
      filename: file,
      startLine: 1,
      endLine: 1,
    );
    final result = directives(spliced);
    expect(accounts(spliced), ['Assets:Cash', 'Assets:Mid', 'Assets:Later']);
    expect(result.directives.map((d) => d.location.linenoBegin).toList(), [1, 2, 3]);
  });

  test('does not replace directives from a different file', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(
      base,
      '2014-01-01 open Assets:Other\n',
      filename: 'other.beancount',
      startLine: 1,
      endLine: 1,
    );
    expect(accounts(spliced), unorderedEquals(['Assets:Cash', 'Assets:Other']));
  });

  test('does not apply an option spliced into a non-root file', () {
    final base = parser.parse('option "title" "Root"\n2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(
      base,
      'option "title" "Other"\n',
      filename: 'other.beancount',
      startLine: 1,
      endLine: 1,
    );
    final result = directives(spliced);
    expect(result.options.title, 'Root');
    expect(result.info.optionSettings.every((setting) => setting.value != 'Other'), isTrue);
    expect(result.warnings.single.message, 'option ignored in included file');
    expect(result.warnings.single.location.filename, 'other.beancount');
  });

  test('does not record a plugin spliced into a non-root file', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(
      base,
      'plugin "beancount.plugins.auto_accounts"\n',
      filename: 'other.beancount',
      startLine: 1,
      endLine: 1,
    );
    expect(directives(spliced).info.plugin, isEmpty);
    expect(directives(spliced).warnings.single.message, 'plugin ignored in included file');
    expect(directives(spliced).warnings.single.location.filename, 'other.beancount');
  });

  test('unknown option spliced into a non-root file still fails', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(
      base,
      'option "not_an_option" "x"\n',
      filename: 'other.beancount',
      startLine: 1,
      endLine: 1,
    );
    expect(spliced, isA<ParsedLedgerErrors>());
    expect((spliced as ParsedLedgerErrors).errors.single.message, 'unknown option');
  });

  test('drops a multi-line transaction that overlaps the replaced span', () {
    final base = parser.parse(
      '2014-01-01 * "Payee"\n  Assets:Cash  1 USD\n  Assets:Cash  -1 USD\n2014-01-02 open Assets:Other\n',
      filename: file,
    );
    final spliced = parser.splice(base, '2014-01-01 open Assets:Cash\n', filename: file, startLine: 1, endLine: 2);
    expect(directives(spliced).directives, hasLength(2));
    expect(directives(spliced).directives.first.body, isA<OpenBody>());
  });

  test('returns snippet errors without keeping leftover directives', () {
    final base = parser.parse('2014-01-01 open Assets:Cash\n', filename: file);
    final spliced = parser.splice(base, 'not a directive\n', filename: file, startLine: 2, endLine: 1);
    expect(spliced, isA<ParsedLedgerErrors>());
  });
}
