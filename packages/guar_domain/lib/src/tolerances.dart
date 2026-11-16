// Inference of per-currency tolerances from the decimal places users write.

import 'package:decimal/decimal.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/cost.dart';
import 'package:guar_domain/src/options.dart';
import 'package:guar_domain/src/posting.dart';

enum ToleranceMode { max, min }

class InferredTolerances {
  InferredTolerances(this._values, {Decimal? fallback}) : fallback = fallback ?? Decimal.zero;

  final Map<String, Decimal> _values;
  final Decimal fallback;

  Decimal operator [](String currency) => _values[currency] ?? fallback;
}

// One posting's inputs to tolerance inference; pending cost is the pre-booking form.
typedef TolerancePosting = ({
  Amount? units,
  Cost? cost,
  Amount? price,
  ({Decimal? numberPer, Decimal? numberTotal, Currency? currency})? pendingCost,
});

final Decimal _maximumTolerance = Decimal.parse('0.5');

InferredTolerances inferBookedTolerances(
  List<Posting> postings,
  LedgerOptions options, {
  ToleranceMode mode = ToleranceMode.max,
}) => inferTolerances(
  <TolerancePosting>[
    for (final Posting posting in postings)
      (units: posting.units, cost: posting.cost, price: posting.price, pendingCost: null),
  ],
  options,
  mode: mode,
);

InferredTolerances inferTolerances(
  List<TolerancePosting> postings,
  LedgerOptions options, {
  ToleranceMode mode = ToleranceMode.max,
}) {
  final bool useCost = options.inferToleranceFromCost;
  final Decimal multiplier = options.inferredToleranceMultiplier.value;
  Decimal agg(Decimal left, Decimal right) => switch (mode) {
    ToleranceMode.max => left > right ? left : right,
    ToleranceMode.min => left < right ? left : right,
  };

  final Set<String> seen = <String>{};
  for (final TolerancePosting posting in postings) {
    final Amount? units = posting.units;
    if (units != null) seen.add(units.currency.name);
    final Cost? cost = posting.cost;
    if (cost != null) seen.add(cost.currency.name);
    final ({Decimal? numberPer, Decimal? numberTotal, Currency? currency})? pending = posting.pendingCost;
    if (pending?.currency != null) seen.add(pending!.currency!.name);
    final Amount? price = posting.price;
    if (price != null) seen.add(price.currency.name);
  }

  final Map<String, Decimal> tolerances = <String, Decimal>{};
  for (final InferredTolerance preset in options.inferredToleranceDefault) {
    switch (preset.key) {
      case CurrencyKeyAll():
        tolerances['*'] = preset.value;
      case CurrencyKeyCurrency(:final Currency value):
        if (seen.contains(value.name)) {
          tolerances[value.name] = preset.value;
        }
    }
  }

  final Map<String, Decimal> costTolerances = <String, Decimal>{};
  for (final TolerancePosting posting in postings) {
    final Amount? units = posting.units;
    if (units == null) continue;
    final int scale = units.scale;
    if (scale <= 0) continue;
    final Decimal tolerance = Decimal.one.shift(-scale) * multiplier;
    final String currency = units.currency.name;
    final Decimal? existing = tolerances[currency];
    tolerances[currency] = existing == null ? tolerance : agg(tolerance, existing);

    if (!useCost) continue;

    final Cost? cost = posting.cost;
    final ({Decimal? numberPer, Decimal? numberTotal, Currency? currency})? pending = posting.pendingCost;
    if (cost != null) {
      final Decimal costTolerance = _minDecimal(tolerance * cost.number.abs(), _maximumTolerance);
      costTolerances.update(
        cost.currency.name,
        (Decimal value) => value + costTolerance,
        ifAbsent: () => costTolerance,
      );
    } else if (pending != null && pending.currency != null) {
      Decimal costTolerance = _maximumTolerance;
      for (final Decimal? number in <Decimal?>[pending.numberTotal, pending.numberPer]) {
        if (number == null) continue;
        costTolerance = _minDecimal(tolerance * number.abs(), costTolerance);
      }
      costTolerances.update(
        pending.currency!.name,
        (Decimal value) => value + costTolerance,
        ifAbsent: () => costTolerance,
      );
    }

    final Amount? price = posting.price;
    if (price != null) {
      final Decimal priceTolerance = _minDecimal(tolerance * price.number.abs(), _maximumTolerance);
      costTolerances.update(
        price.currency.name,
        (Decimal value) => value + priceTolerance,
        ifAbsent: () => priceTolerance,
      );
    }
  }

  for (final MapEntry<String, Decimal> entry in costTolerances.entries) {
    final Decimal? existing = tolerances[entry.key];
    tolerances[entry.key] = existing == null ? entry.value : agg(entry.value, existing);
  }

  final Decimal fallback = tolerances.remove('*') ?? Decimal.zero;
  return InferredTolerances(tolerances, fallback: fallback);
}

Decimal _minDecimal(Decimal left, Decimal right) => left < right ? left : right;
