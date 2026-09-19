// Shared plumbing for stock plugin tests: run a snippet through Book.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

Ledger process(String source, {String filename = 'plugin_test.beancount', bool recover = false}) =>
    Book().process(const p.BeancountParser().parse(source, filename: filename), recover: recover);

List<Directive> booked(String source, {bool recover = false}) {
  final Ledger ledger = process(source, recover: recover);
  return switch (ledger) {
    LedgerDirectives(:final List<Directive> directives) => directives,
    LedgerErrors(:final List<ProcessingError> errors) => throw TestFailure(
      errors.map((ProcessingError error) => error.message).join('\n'),
    ),
  };
}

List<String> messages(String source) {
  final Ledger ledger = process(source);
  return switch (ledger) {
    LedgerDirectives() => const <String>[],
    LedgerErrors(:final List<ProcessingError> errors) => <String>[
      for (final ProcessingError error in errors) error.message,
    ],
  };
}

List<String> opens(List<Directive> directives) => <String>[
  for (final Directive directive in directives)
    if (directive.body case OpenBody(:final Account account)) account.name,
];

List<String> closes(List<Directive> directives) => <String>[
  for (final Directive directive in directives)
    if (directive.body case CloseBody(:final Account account)) '${date(directive)} ${account.name}',
];

List<String> balances(List<Directive> directives) => <String>[
  for (final Directive directive in directives)
    if (directive.body case BalanceBody(:final Account account, :final Amount amount))
      '${date(directive)} ${account.name} $amount',
];

String date(Directive directive) => '${directive.date}';
