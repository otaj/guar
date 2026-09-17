// Insert Open directives for accounts first used without an open.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult autoInsertOpen(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final opened = {
    for (final directive in directives)
      if (directive.body case OpenBody(:final account)) account.name,
  };
  final firstUse = accountFirstUse(directives);
  final inserts = <Directive>[];
  final accounts = firstUse.keys.toList()..sort();
  for (final account in accounts) {
    if (opened.contains(account)) continue;
    final date = firstUse[account]!;
    inserts.add(
      Directive(
        origin: const Origin.generated(),
        date: date,
        body: DirectiveBody.open(account: generatedAccount(account, options)),
      ),
    );
  }
  if (inserts.isEmpty) {
    return (directives: directives, errors: const []);
  }
  final merged = [...inserts, ...directives]..sort(compareDirectiveDate);
  return (directives: merged, errors: const []);
}
