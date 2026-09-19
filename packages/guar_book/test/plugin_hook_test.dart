// Plugin registry wiring for Book.process.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('unregistered plugin yields processing error', () {
    final p.ParsedLedger parsed = p.ParsedLedger.directives(
      directives: const <p.ParsedDirective>[],
      info: p.ProcessingInfo(
        plugin: <p.Plugin>[
          p.Plugin(name: 'custom.unknown.plugin', location: p.BeanLocation(linenoBegin: 1, linenoEnd: 1)),
        ],
      ),
    );
    final Ledger ledger = Book().process(parsed);
    expect(ledger, isA<LedgerErrors>());
    final List<ProcessingError> errors = (ledger as LedgerErrors).errors;
    expect(errors.single.message, contains('plugin not registered'));
  });

  test('registered plugin can rewrite directives', () {
    final p.ParsedLedger parsed = p.ParsedLedger.directives(
      directives: <p.ParsedDirective>[
        p.ParsedDirective(
          location: p.BeanLocation(linenoBegin: 1, linenoEnd: 1),
          date: p.BeanDate(year: 2020, month: 1, day: 1),
          body: p.DirectiveBody.open(account: p.Account(name: 'Assets:Cash')),
        ),
      ],
      info: p.ProcessingInfo(
        plugin: <p.Plugin>[
          p.Plugin(
            name: 'test.set_title_meta',
            config: 'hello',
            location: p.BeanLocation(linenoBegin: 2, linenoEnd: 2),
          ),
        ],
      ),
    );

    final Book book = Book(
      plugins: <String, BookPlugin>{
        'test.set_title_meta':
            (List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) => (
              directives: <Directive>[
                for (final Directive directive in directives)
                  directive.copyWith(
                    meta: Meta(
                      entries: <MetaEntry>[MetaEntry(key: 'cfg', value: MetaValue.text(config ?? ''))],
                    ),
                  ),
              ],
              errors: const <ProcessingError>[],
            ),
      },
    );

    final Ledger ledger = book.process(parsed);
    expect(ledger, isA<LedgerDirectives>());
    final List<Directive> directives = (ledger as LedgerDirectives).directives;
    expect(directives.single.meta.entries.single.key, 'cfg');
    expect(directives.single.meta.entries.single.value, const MetaValue.text('hello'));
  });

  test('stock plugin name resolves without manual registration', () {
    final p.ParsedLedger parsed = const p.BeancountParser().parse(
      'plugin "beancount.plugins.auto_accounts"\n'
      '2014-02-01 *\n'
      '  Assets:Cash  10 USD\n'
      '  Equity:Opening  -10 USD\n',
      filename: 'ledger.beancount',
    );
    final Ledger ledger = Book().process(parsed);
    expect(ledger, isA<LedgerDirectives>());
    final List<String> opens = <String>[
      for (final Directive d in (ledger as LedgerDirectives).directives)
        if (d.body is OpenBody) (d.body as OpenBody).account.name,
    ];
    expect(opens, containsAll(<dynamic>['Assets:Cash', 'Equity:Opening']));
  });

  test('reds plugin name resolves without manual registration', () {
    final p.ParsedLedger parsed = const p.BeancountParser().parse(
      'plugin "beancount_reds_plugins.rename_accounts.rename_accounts" "{\'Expenses:Taxes\': \'Income:Taxes\'}"\n'
      '2014-01-01 open Expenses:Taxes\n'
      '2014-01-01 open Assets:Cash\n'
      '2014-01-16 *\n'
      '  Assets:Cash        -10 USD\n'
      '  Expenses:Taxes      10 USD\n',
      filename: 'ledger.beancount',
    );
    final Ledger ledger = Book().process(parsed);
    expect(ledger, isA<LedgerDirectives>());
    final List<String> names = <String>[
      for (final Directive d in (ledger as LedgerDirectives).directives)
        if (d.body case OpenBody(:final Account account)) account.name,
    ];
    expect(names, contains('Income:Taxes'));
    expect(names, isNot(contains('Expenses:Taxes')));
  });
}
