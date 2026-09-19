// Rename accounts by regex, matching beancount_reds_plugins.rename_accounts.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

BookPluginResult renameAccounts(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for rename_accounts plugin; skipping.');
  }
  final Map<Object?, Object?> map = parsed.map!;
  final List<(RegExp, String)> renames = <(RegExp, String)>[];
  for (final MapEntry<Object?, Object?> entry in map.entries) {
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
    String current = account;
    for (final (RegExp, String) rule in renames) {
      current = pythonSub(rule.$1, rule.$2, current).result;
    }
    return current;
  }

  final List<Directive> rewritten = <Directive>[
    for (final Directive directive in directives) rewriteDirectiveAccounts(directive, rename, options),
  ];
  final Set<String> seenOpens = <String>{};
  return (
    directives: <Directive>[
      for (final Directive directive in rewritten)
        if (directive.body case OpenBody(:final Account account))
          if (seenOpens.add(account.name)) directive else ...<Directive>[]
        else
          directive,
    ],
    errors: const <ProcessingError>[],
  );
}
