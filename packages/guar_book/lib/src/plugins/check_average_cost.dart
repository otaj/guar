// Keep reducing legs of NONE-booked accounts near the running average cost.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'config_literal.dart';
import 'helpers.dart';

final Decimal _defaultTolerance = Decimal.parse('0.01');

BookPluginResult validateAverageCost(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  var tolerance = _defaultTolerance;
  if (config != null && config.trim().isNotEmpty) {
    final parsed = parseConfigLiteral(config);
    final value = parsed.value;
    if (parsed.error != null || value is! double) {
      return (
        directives: directives,
        errors: [
          ProcessingError(
            message: 'Invalid configuration for check_average_cost: must be a float',
            location: nowhereLocation('<check_average_cost>'),
          ),
        ],
      );
    }
    tolerance = Decimal.parse(value.toString());
  }
  final minTolerance = Decimal.one - tolerance;
  final maxTolerance = Decimal.one + tolerance;

  final openClose = accountOpenClose(directives);
  final units = <String, Decimal>{};
  final costs = <String, Decimal>{};
  final errors = <ProcessingError>[];

  for (final directive in directives) {
    if (directive.body case TransactionBody(:final value)) {
      for (final posting in value.postings) {
        final open = openClose[posting.account.name]?.open;
        if (open == null || (open.body as OpenBody).booking != BookingMethod.none) continue;
        final cost = posting.cost;
        final key = '${posting.account.name}|${posting.units.currency.name}|${cost?.currency.name}';
        if (posting.units.number < Decimal.zero && cost != null) {
          final heldUnits = units[key] ?? Decimal.zero;
          final heldCost = costs[key] ?? Decimal.zero;
          if (heldUnits != Decimal.zero) {
            final average = (heldCost / heldUnits).toDecimal(scaleOnInfinitePrecision: 28);
            final minValid = average * minTolerance;
            final maxValid = average * maxTolerance;
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
