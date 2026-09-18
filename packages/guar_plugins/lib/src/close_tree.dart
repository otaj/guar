// Close every still-open descendant when an account tree is closed.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult closeTree(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final opens = <String>{};
  final closes = <String>{};
  for (final directive in directives) {
    switch (directive.body) {
      case OpenBody(:final account):
        opens.add(account.name);
      case CloseBody(:final account):
        closes.add(account.name);
      default:
        break;
    }
  }

  final out = <Directive>[];
  for (final directive in directives) {
    if (directive.body case CloseBody(:final account)) {
      final subaccounts = [
        for (final open in opens)
          if (isSubaccountName(open, account.name) && !closes.contains(open)) open,
      ]..sort();
      for (final subaccount in subaccounts) {
        out.add(
          Directive(
            origin: const Origin.generated(),
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
  return (directives: out, errors: const []);
}
