// Reject more than one distinct price per date and base/quote currency pair.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateUniquePrices(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Map<String, List<Directive>> prices = <String, List<Directive>>{};
  for (final Directive directive in directives) {
    if (directive.body case PriceBody(:final Currency currency, :final Amount amount)) {
      final String key =
          '${directive.date}|'
          '${currency.name}|${amount.currency.name}';
      prices.putIfAbsent(key, () => <Directive>[]).add(directive);
    }
  }

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final List<Directive> group in prices.values) {
    if (group.length < 2) continue;
    final Map<Decimal, Directive> byNumber = <Decimal, Directive>{};
    for (final Directive directive in group) {
      byNumber[(directive.body as PriceBody).amount.number] = directive;
    }
    if (byNumber.length > 1) {
      errors.add(
        ProcessingError(message: 'Disagreeing price entries', location: directiveLocation(byNumber.values.first)),
      );
    }
  }
  return (directives: directives, errors: errors);
}
