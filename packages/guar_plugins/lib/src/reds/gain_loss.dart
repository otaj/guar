// Rebook capital-gains postings into separate gains and losses accounts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

BookPluginResult gainLoss(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
  }
  final rewrites = <(RegExp, String, String, String)>[];
  for (final entry in parsed.map!.entries) {
    if (entry.key is! String || entry.value is! List) {
      return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
    }
    final spec = entry.value! as List<Object?>;
    if (spec.length < 3 || spec[0] is! String || spec[1] is! String || spec[2] is! String) {
      return configError(directives, 'Invalid configuration for gain_loss plugin; skipping.');
    }
    rewrites.add((pythonRegExp(entry.key! as String), spec[0]! as String, spec[1]! as String, spec[2]! as String));
  }

  final newAccounts = <String>{};
  final out = <Directive>[];
  for (final directive in directives) {
    final transaction = transactionOf(directive);
    if (transaction == null) {
      out.add(directive);
      continue;
    }
    final postings = <Posting>[];
    var changed = false;
    for (final posting in transaction.postings) {
      var account = posting.account.name;
      for (final rule in rewrites) {
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
  return (directives: [...createOpenDirectives(newAccounts, directives, options), ...out], errors: const []);
}
