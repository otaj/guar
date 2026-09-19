// Close every still-open descendant when an account tree is closed.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult closeTree(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final Set<String> opens = <String>{};
  final Set<String> closes = <String>{};
  for (final Directive directive in directives) {
    switch (directive.body) {
      case OpenBody(:final Account account):
        opens.add(account.name);
      case CloseBody(:final Account account):
        closes.add(account.name);
      default:
        break;
    }
  }

  final List<Directive> out = <Directive>[];
  for (final Directive directive in directives) {
    if (directive.body case CloseBody(:final Account account)) {
      final List<String> subaccounts = <String>[
        for (final String open in opens)
          if (isSubaccountName(open, account.name) && !closes.contains(open)) open,
      ]..sort();
      for (final String subaccount in subaccounts) {
        out.add(
          Directive(
            origin: insertOrigin(
              date: directive.date,
              body: DirectiveBody.close(account: generatedAccount(subaccount, options)),
              existing: directives,
              info: info,
            ),
            date: directive.date,
            body: DirectiveBody.close(account: generatedAccount(subaccount, options)),
          ),
        );
        // Recorded so a grandchild closed here is not closed again by a child.
        closes.add(subaccount);
      }
      if (opens.contains(account.name)) {
        out.add(directive);
      }
      continue;
    }
    out.add(directive);
  }
  return (directives: out, errors: const <ProcessingError>[]);
}
