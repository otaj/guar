// Restrict each account to a single units commodity and a single cost commodity.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateOneCommodity(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final RegExp? accountsRe = (config == null || config.isEmpty) ? null : RegExp(config);

  final Map<String, Set<String>> unitsMap = <String, Set<String>>{};
  final Map<String, Set<String>> costMap = <String, Set<String>>{};
  final Map<String, Directive> unitsSource = <String, Directive>{};
  final Map<String, Directive> costSource = <String, Directive>{};
  final Set<String> skip = <String>{};

  for (final Directive directive in directives) {
    if (directive.body case OpenBody(:final Account account, :final List<Currency> currencies)) {
      final bool disabled = directive.meta.lookup('onecommodity') == const MetaValue.boolean(false);
      final bool unmatched = accountsRe != null && accountsRe.matchAsPrefix(account.name) == null;
      if (disabled || unmatched || currencies.length > 1) {
        skip.add(account.name);
      }
    }
  }

  for (final Directive directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          final String name = posting.account.name;
          if (skip.contains(name)) continue;
          final Set<String> units = unitsMap.putIfAbsent(name, () => <String>{})..add(posting.units.currency.name);
          if (units.length > 1) {
            unitsSource[name] = directive;
          }
          final Cost? cost = posting.cost;
          if (cost != null) {
            final Set<String> costs = costMap.putIfAbsent(name, () => <String>{})..add(cost.currency.name);
            if (costs.length > 1) {
              costSource[name] = directive;
            }
          }
        }
      case BalanceBody(:final Account account, :final Amount amount):
        final String name = account.name;
        if (skip.contains(name)) continue;
        final Set<String> units = unitsMap.putIfAbsent(name, () => <String>{});
        units.add(amount.currency.name);
        if (units.length > 1) {
          unitsSource[name] = directive;
        }
      default:
        break;
    }
  }

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final MapEntry<String, Set<String>> entry in unitsMap.entries) {
    if (skip.contains(entry.key) || entry.value.length < 2) continue;
    errors.add(
      ProcessingError(
        message: "More than one currency in account '${entry.key}': ${entry.value.join(',')}",
        location: directiveLocation(unitsSource[entry.key]!),
      ),
    );
  }
  for (final MapEntry<String, Set<String>> entry in costMap.entries) {
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
