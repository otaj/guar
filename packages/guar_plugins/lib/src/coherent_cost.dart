// Reject commodities that are posted both at cost and without cost.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult validateCoherentCost(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final withCost = <String, Directive>{};
  final withoutCost = <String, Directive>{};
  for (final directive in directives) {
    if (directive.body case TransactionBody(:final value)) {
      for (final posting in value.postings) {
        final target = posting.cost == null ? withoutCost : withCost;
        target.putIfAbsent(posting.units.currency.name, () => directive);
      }
    }
  }

  final errors = <ProcessingError>[];
  for (final currency in withCost.keys) {
    final plain = withoutCost[currency];
    if (plain == null) continue;
    errors.add(
      ProcessingError(
        message: "Currency '$currency' is used both with and without cost",
        location: directiveLocation(plain),
      ),
    );
  }
  return (directives: directives, errors: errors);
}
