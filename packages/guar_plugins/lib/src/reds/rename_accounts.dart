// Rename accounts by regex, matching beancount_reds_plugins.rename_accounts.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

BookPluginResult renameAccounts(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for rename_accounts plugin; skipping.');
  }
  final map = parsed.map!;
  final renames = <(RegExp, String)>[];
  for (final entry in map.entries) {
    if (entry.key is! String || entry.value is! String) {
      return configError(directives, 'Invalid configuration for rename_accounts plugin; skipping.');
    }
    try {
      renames.add((pythonRegExp(entry.key! as String), entry.value! as String));
    } on FormatException {
      return configError(directives, 'Invalid configuration for rename_accounts plugin; skipping.');
    }
  }

  String rename(String account) {
    var current = account;
    for (final rule in renames) {
      current = pythonSub(rule.$1, rule.$2, current).result;
    }
    return current;
  }

  final rewritten = [for (final directive in directives) rewriteDirectiveAccounts(directive, rename, options)];
  final seenOpens = <String>{};
  return (
    directives: [
      for (final directive in rewritten)
        if (directive.body case OpenBody(:final account))
          if (seenOpens.add(account.name)) directive else ...<Directive>[]
        else
          directive,
    ],
    errors: const [],
  );
}
