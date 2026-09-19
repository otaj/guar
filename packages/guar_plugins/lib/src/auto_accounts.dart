// Insert Open directives for accounts first used without an open.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult autoInsertOpen(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Set<String> opened = <String>{
    for (final Directive directive in directives)
      if (directive.body case OpenBody(:final Account account)) account.name,
  };
  final Map<String, BeanDate> firstUse = accountFirstUse(directives);
  final List<Directive> inserts = <Directive>[];
  final List<String> accounts = firstUse.keys.toList()..sort();
  for (final String account in accounts) {
    if (opened.contains(account)) continue;
    final BeanDate date = firstUse[account]!;
    inserts.add(
      Directive(
        origin: insertOrigin(
          date: date,
          body: DirectiveBody.open(account: generatedAccount(account, options)),
          existing: directives,
          info: info,
        ),
        date: date,
        body: DirectiveBody.open(account: generatedAccount(account, options)),
      ),
    );
  }
  if (inserts.isEmpty) {
    return (directives: directives, errors: const <ProcessingError>[]);
  }
  final List<Directive> merged = <Directive>[...inserts, ...directives]..sort(compareDirectiveDate);
  return (directives: merged, errors: const <ProcessingError>[]);
}
