// Shared plumbing for stock plugin tests: run a snippet through Book.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

Ledger process(String source, {String filename = 'plugin_test.beancount'}) =>
    Book().process(p.BeancountParser().parse(source, filename: filename));

List<Directive> booked(String source) {
  final ledger = process(source);
  return switch (ledger) {
    LedgerDirectives(:final directives) => directives,
    LedgerErrors(:final errors) => throw TestFailure(errors.map((error) => error.message).join('\n')),
  };
}

List<String> messages(String source) {
  final ledger = process(source);
  return switch (ledger) {
    LedgerDirectives() => const [],
    LedgerErrors(:final errors) => [for (final error in errors) error.message],
  };
}

List<String> opens(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case OpenBody(:final account)) account.name,
];

List<String> closes(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case CloseBody(:final account)) '${date(directive)} ${account.name}',
];

List<String> balances(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case BalanceBody(:final account, :final amount)) '${date(directive)} ${account.name} $amount',
];

String date(Directive directive) => '${directive.date}';
