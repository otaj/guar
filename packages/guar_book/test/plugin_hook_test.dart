// Plugin registry wiring for Book.process.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('unregistered plugin yields processing error', () {
    final parsed = p.ParsedLedger.directives(
      directives: const [],
      info: p.ProcessingInfo(
        plugin: [p.Plugin(name: 'custom.unknown.plugin', location: const p.BeanLocation(linenoBegin: 1, linenoEnd: 1))],
      ),
    );
    final ledger = Book().process(parsed);
    expect(ledger, isA<LedgerErrors>());
    final errors = (ledger as LedgerErrors).errors;
    expect(errors.single.message, contains('plugin not registered'));
  });

  test('registered plugin can rewrite directives', () {
    final parsed = p.ParsedLedger.directives(
      directives: [
        p.ParsedDirective(
          location: const p.BeanLocation(linenoBegin: 1, linenoEnd: 1),
          date: const p.BeanDate(year: 2020, month: 1, day: 1),
          body: p.DirectiveBody.open(account: const p.Account(name: 'Assets:Cash')),
        ),
      ],
      info: p.ProcessingInfo(
        plugin: [
          p.Plugin(
            name: 'test.set_title_meta',
            config: 'hello',
            location: const p.BeanLocation(linenoBegin: 2, linenoEnd: 2),
          ),
        ],
      ),
    );

    final book = Book(
      plugins: {
        'test.set_title_meta': (directives, options, info, config) {
          return (
            directives: [
              for (final directive in directives)
                directive.copyWith(
                  meta: Meta(
                    entries: [MetaEntry(key: 'cfg', value: MetaValue.text(config ?? ''))],
                  ),
                ),
            ],
            errors: const <ProcessingError>[],
          );
        },
      },
    );

    final ledger = book.process(parsed);
    expect(ledger, isA<LedgerDirectives>());
    final directives = (ledger as LedgerDirectives).directives;
    expect(directives.single.meta.entries.single.key, 'cfg');
    expect(directives.single.meta.entries.single.value, const MetaValue.text('hello'));
  });
}
