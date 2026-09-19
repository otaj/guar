// Keep reducing legs of NONE-booked accounts near the running average cost.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

final Decimal _defaultTolerance = Decimal.parse('0.01');

BookPluginResult validateAverageCost(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  Decimal tolerance = _defaultTolerance;
  if (config != null && config.trim().isNotEmpty) {
    final ConfigLiteral parsed = parseConfigLiteral(config);
    final Object? value = parsed.value;
    if (parsed.error != null || value is! double) {
      return (
        directives: directives,
        errors: <ProcessingError>[
          ProcessingError(
            message: 'Invalid configuration for check_average_cost: must be a float',
            location: nowhereLocation('<check_average_cost>'),
          ),
        ],
      );
    }
    tolerance = Decimal.parse(value.toString());
  }
  final Decimal minTolerance = Decimal.one - tolerance;
  final Decimal maxTolerance = Decimal.one + tolerance;

  final Map<String, ({Directive? close, Directive? open})> openClose = accountOpenClose(directives);
  final Map<String, Decimal> units = <String, Decimal>{};
  final Map<String, Decimal> costs = <String, Decimal>{};
  final List<ProcessingError> errors = <ProcessingError>[];

  for (final Directive directive in directives) {
    if (directive.body case TransactionBody(:final Transaction value)) {
      for (final Posting posting in value.postings) {
        final Directive? open = openClose[posting.account.name]?.open;
        if (open == null || (open.body as OpenBody).booking != BookingMethod.none) continue;
        final Cost? cost = posting.cost;
        final String key = '${posting.account.name}|${posting.units.currency.name}|${cost?.currency.name}';
        if (posting.units.number < Decimal.zero && cost != null) {
          final Decimal heldUnits = units[key] ?? Decimal.zero;
          final Decimal heldCost = costs[key] ?? Decimal.zero;
          if (heldUnits != Decimal.zero) {
            final Decimal average = (heldCost / heldUnits).toDecimal(scaleOnInfinitePrecision: 28);
            final Decimal minValid = average * minTolerance;
            final Decimal maxValid = average * maxTolerance;
            if (cost.number < minValid || cost.number > maxValid) {
              errors.add(
                ProcessingError(
                  message:
                      'Cost basis on reducing posting is too far from '
                      'the average cost (${cost.number} vs. $average)',
                  location: directiveLocation(directive),
                ),
              );
            }
          }
        }
        units[key] = (units[key] ?? Decimal.zero) + posting.units.number;
        costs[key] = (costs[key] ?? Decimal.zero) + posting.units.number * (cost?.number ?? Decimal.zero);
      }
    }
  }
  return (directives: directives, errors: errors);
}
