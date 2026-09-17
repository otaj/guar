// Restrict each account to a single units commodity and a single cost commodity.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult validateOneCommodity(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final accountsRe = (config == null || config.isEmpty) ? null : RegExp(config);

  final unitsMap = <String, Set<String>>{};
  final costMap = <String, Set<String>>{};
  final unitsSource = <String, Directive>{};
  final costSource = <String, Directive>{};
  final skip = <String>{};

  for (final directive in directives) {
    if (directive.body case OpenBody(:final account, :final currencies)) {
      final disabled = directive.meta.lookup('onecommodity') == MetaValue.boolean(false);
      final unmatched = accountsRe != null && accountsRe.matchAsPrefix(account.name) == null;
      if (disabled || unmatched || currencies.length > 1) {
        skip.add(account.name);
      }
    }
  }

  for (final directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          final name = posting.account.name;
          if (skip.contains(name)) continue;
          final units = unitsMap.putIfAbsent(name, () => <String>{});
          units.add(posting.units.currency.name);
          if (units.length > 1) {
            unitsSource[name] = directive;
          }
          final cost = posting.cost;
          if (cost != null) {
            final costs = costMap.putIfAbsent(name, () => <String>{});
            costs.add(cost.currency.name);
            if (costs.length > 1) {
              costSource[name] = directive;
            }
          }
        }
      case BalanceBody(:final account, :final amount):
        final name = account.name;
        if (skip.contains(name)) continue;
        final units = unitsMap.putIfAbsent(name, () => <String>{});
        units.add(amount.currency.name);
        if (units.length > 1) {
          unitsSource[name] = directive;
        }
      default:
        break;
    }
  }

  final errors = <ProcessingError>[];
  for (final entry in unitsMap.entries) {
    if (skip.contains(entry.key) || entry.value.length < 2) continue;
    errors.add(
      ProcessingError(
        message: "More than one currency in account '${entry.key}': ${entry.value.join(',')}",
        location: directiveLocation(unitsSource[entry.key]!),
      ),
    );
  }
  for (final entry in costMap.entries) {
    if (skip.contains(entry.key) || entry.value.length < 2) continue;
    errors.add(
      ProcessingError(
        message: "More than one cost currency in account '${entry.key}': ${entry.value.join(',')}",
        location: directiveLocation(costSource[entry.key]!),
      ),
    );
  }
  return (directives: directives, errors: errors);
}
