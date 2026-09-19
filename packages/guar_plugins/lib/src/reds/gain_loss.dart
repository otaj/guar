// Rebook capital-gains postings into separate gains and losses accounts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

BookPluginResult gainLoss(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
  }
  final List<(RegExp, String, String, String)> rewrites = <(RegExp, String, String, String)>[];
  for (final MapEntry<Object?, Object?> entry in parsed.map!.entries) {
    if (entry.key is! String || entry.value is! List) {
      return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
    }
    final List<Object?> spec = entry.value! as List<Object?>;
    if (spec.length < 3 || spec[0] is! String || spec[1] is! String || spec[2] is! String) {
      return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
    }
    rewrites.add((pythonRegExp(entry.key! as String), spec[0]! as String, spec[1]! as String, spec[2]! as String));
  }

  final Set<String> newAccounts = <String>{};
  final List<Directive> out = <Directive>[];
  for (final Directive directive in directives) {
    final Transaction? transaction = transactionOf(directive);
    if (transaction == null) {
      out.add(directive);
      continue;
    }
    final List<Posting> postings = <Posting>[];
    bool changed = false;
    for (final Posting posting in transaction.postings) {
      String account = posting.account.name;
      for (final (RegExp, String, String, String) rule in rewrites) {
        if (!rule.$1.hasMatch(account)) continue;
        account = posting.units.number < Decimal.zero
            ? account.replaceAll(rule.$2, rule.$3)
            : account.replaceAll(rule.$2, rule.$4);
        changed = true;
        break;
      }
      if (account != posting.account.name) newAccounts.add(account);
      postings.add(
        account == posting.account.name ? posting : posting.copyWith(account: rewriteAccount(account, options)),
      );
    }
    out.add(changed ? replaceTransaction(directive, transaction.copyWith(postings: postings)) : directive);
  }
  return (
    directives: <Directive>[...createOpenDirectives(newAccounts, directives, options, info), ...out],
    errors: const <ProcessingError>[],
  );
}
