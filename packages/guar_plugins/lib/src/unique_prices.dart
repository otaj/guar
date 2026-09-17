// Reject more than one distinct price per date and base/quote currency pair.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult validateUniquePrices(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final prices = <String, List<Directive>>{};
  for (final directive in directives) {
    if (directive.body case PriceBody(:final currency, :final amount)) {
      final key =
          '${directive.date}|'
          '${currency.name}|${amount.currency.name}';
      prices.putIfAbsent(key, () => <Directive>[]).add(directive);
    }
  }

  final errors = <ProcessingError>[];
  for (final group in prices.values) {
    if (group.length < 2) continue;
    final byNumber = <Decimal, Directive>{};
    for (final directive in group) {
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
