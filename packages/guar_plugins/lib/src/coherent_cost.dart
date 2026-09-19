// Reject commodities that are posted both at cost and without cost.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateCoherentCost(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Map<String, Directive> withCost = <String, Directive>{};
  final Map<String, Directive> withoutCost = <String, Directive>{};
  for (final Directive directive in directives) {
    if (directive.body case TransactionBody(:final Transaction value)) {
      for (final Posting posting in value.postings) {
        (posting.cost == null ? withoutCost : withCost).putIfAbsent(posting.units.currency.name, () => directive);
      }
    }
  }

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final String currency in withCost.keys) {
    final Directive? plain = withoutCost[currency];
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
