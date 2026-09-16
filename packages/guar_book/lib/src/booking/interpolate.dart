// Interpolate a currency group and convert remaining CostSpecs to Costs.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

class MutablePosting {
  MutablePosting({
    required this.origin,
    required this.meta,
    this.flag,
    required this.account,
    this.units,
    this.cost,
    this.pendingCost,
    this.price,
  });

  final Origin origin;
  final Meta meta;
  final Flag? flag;
  final Account account;
  Amount? units;
  Cost? cost;
  PendingCost? pendingCost;
  Amount? price;

  Posting toPosting() {
    final resolvedUnits = units;
    if (resolvedUnits == null) {
      throw StateError('incomplete units');
    }
    return Posting(
      origin: origin,
      meta: meta,
      flag: flag,
      account: account,
      units: resolvedUnits,
      cost: cost,
      price: price,
    );
  }
}

class PendingCost {
  PendingCost({this.numberPer, this.numberTotal, this.currency, required this.date, this.label});

  Decimal? numberPer;
  Decimal? numberTotal;
  Currency? currency;
  final BeanDate date;
  final String? label;

  bool get isComplete => numberPer != null || numberTotal != null;

  Cost? toCost(Decimal unitsAbs) {
    final resolvedCurrency = currency;
    if (resolvedCurrency == null) {
      return null;
    }
    if (numberTotal != null) {
      var total = numberTotal!;
      if (numberPer != null) {
        total += numberPer! * unitsAbs;
      }
      if (unitsAbs == Decimal.zero) {
        return null;
      }
      return Cost(
        number: (total / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28),
        currency: resolvedCurrency,
        date: date,
        label: label,
      );
    }
    if (numberPer == null) {
      return null;
    }
    return Cost(number: numberPer!, currency: resolvedCurrency, date: date, label: label);
  }
}

Amount postingWeight(MutablePosting posting) {
  final units = posting.units!;
  if (posting.cost != null) {
    return Amount(number: units.number * posting.cost!.number, currency: posting.cost!.currency);
  }
  if (posting.pendingCost != null && posting.pendingCost!.numberPer != null && posting.pendingCost!.currency != null) {
    return Amount(number: units.number * posting.pendingCost!.numberPer!, currency: posting.pendingCost!.currency!);
  }
  if (posting.price != null) {
    return Amount(number: units.number * posting.price!.number, currency: posting.price!.currency);
  }
  return units;
}

enum ToleranceMode { max, min }

class InferredTolerances {
  InferredTolerances(this._values, {Decimal? fallback}) : fallback = fallback ?? Decimal.zero;

  final Map<String, Decimal> _values;
  final Decimal fallback;

  Decimal operator [](String currency) => _values[currency] ?? fallback;
}

final Decimal _maximumTolerance = Decimal.parse('0.5');
const _maxToleranceDigits = 5;

InferredTolerances inferPostingTolerances(
  List<Posting> postings,
  LedgerOptions options, {
  ToleranceMode mode = ToleranceMode.max,
}) {
  return inferTolerances(
    [
      for (final posting in postings)
        MutablePosting(
          origin: posting.origin,
          meta: posting.meta,
          account: posting.account,
          units: posting.units,
          cost: posting.cost,
          price: posting.price,
        ),
    ],
    options,
    mode: mode,
  );
}

InferredTolerances inferTolerances(
  List<MutablePosting> postings,
  LedgerOptions options, {
  ToleranceMode mode = ToleranceMode.max,
}) {
  final useCost = options.inferToleranceFromCost ?? false;
  final multiplier = options.toleranceMultiplier ?? Decimal.parse('0.5');
  Decimal agg(Decimal left, Decimal right) => switch (mode) {
    ToleranceMode.max => left > right ? left : right,
    ToleranceMode.min => left < right ? left : right,
  };

  final seen = <String>{};
  for (final posting in postings) {
    final units = posting.units;
    if (units != null) seen.add(units.currency.name);
    final cost = posting.cost;
    if (cost != null) seen.add(cost.currency.name);
    final pending = posting.pendingCost;
    if (pending?.currency != null) seen.add(pending!.currency!.name);
    final price = posting.price;
    if (price != null) seen.add(price.currency.name);
  }

  final tolerances = <String, Decimal>{};
  for (final preset in options.inferredToleranceDefault) {
    switch (preset.key) {
      case CurrencyKeyAll():
        tolerances['*'] = preset.value;
      case CurrencyKeyCurrency(:final value):
        if (seen.contains(value.name)) {
          tolerances[value.name] = preset.value;
        }
    }
  }

  final costTolerances = <String, Decimal>{};
  for (final posting in postings) {
    final units = posting.units;
    if (units == null) continue;
    final scale = units.scale;
    if (scale <= 0) continue;
    final tolerance = Decimal.one.shift(-scale) * multiplier;
    final currency = units.currency.name;
    final existing = tolerances[currency];
    tolerances[currency] = existing == null ? tolerance : agg(tolerance, existing);

    if (!useCost) continue;

    final cost = posting.cost;
    final pending = posting.pendingCost;
    if (cost != null) {
      final costTolerance = _minDecimal(tolerance * cost.number.abs(), _maximumTolerance);
      costTolerances.update(cost.currency.name, (value) => value + costTolerance, ifAbsent: () => costTolerance);
    } else if (pending != null && pending.currency != null) {
      var costTolerance = _maximumTolerance;
      for (final number in [pending.numberTotal, pending.numberPer]) {
        if (number == null) continue;
        costTolerance = _minDecimal(tolerance * number.abs(), costTolerance);
      }
      costTolerances.update(pending.currency!.name, (value) => value + costTolerance, ifAbsent: () => costTolerance);
    }

    final price = posting.price;
    if (price != null) {
      final priceTolerance = _minDecimal(tolerance * price.number.abs(), _maximumTolerance);
      costTolerances.update(price.currency.name, (value) => value + priceTolerance, ifAbsent: () => priceTolerance);
    }
  }

  for (final entry in costTolerances.entries) {
    final existing = tolerances[entry.key];
    tolerances[entry.key] = existing == null ? entry.value : agg(entry.value, existing);
  }

  final fallback = tolerances.remove('*') ?? Decimal.zero;
  return InferredTolerances(tolerances, fallback: fallback);
}

Decimal quantizeWithTolerance(InferredTolerances tolerances, String currency, Decimal number) {
  final tolerance = tolerances[currency];
  if (tolerance == Decimal.zero) return number;
  final quantum = tolerance * Decimal.fromInt(2);
  if (_coefficientDigits(quantum) >= _maxToleranceDigits) return number;
  if (quantum == Decimal.zero) return number;
  final rounded = (number / quantum).round();
  return quantum * Decimal.fromBigInt(rounded);
}

Decimal _minDecimal(Decimal left, Decimal right) => left < right ? left : right;

int _coefficientDigits(Decimal number) {
  final digits = number.abs().toString().replaceAll('.', '').replaceFirst(RegExp(r'^0+'), '');
  return digits.isEmpty ? 1 : digits.length;
}

({List<MutablePosting> postings, List<ProcessingError> errors}) interpolateGroup(
  List<MutablePosting> postings,
  Currency weightCurrency,
  BeanLocation location,
  InferredTolerances tolerances,
) {
  final incomplete = <int>[];
  for (var i = 0; i < postings.length; i++) {
    final posting = postings[i];
    if (posting.units == null) {
      incomplete.add(i);
    } else if (posting.pendingCost != null && !posting.pendingCost!.isComplete) {
      incomplete.add(i);
    }
  }

  if (incomplete.length > 1) {
    return (
      postings: postings,
      errors: [
        ProcessingError(
          message: 'Too many missing numbers for currency group "${weightCurrency.name}"',
          location: location,
        ),
      ],
    );
  }

  if (incomplete.length == 1) {
    final index = incomplete.single;
    final target = postings[index];
    var residual = Decimal.zero;
    for (var i = 0; i < postings.length; i++) {
      if (i == index) continue;
      final posting = postings[i];
      if (posting.units == null) continue;
      final weight = postingWeight(posting);
      if (weight.currency != weightCurrency) {
        continue;
      }
      residual += weight.number;
    }
    final fill = -residual;
    if (target.units == null) {
      target.units = Amount(
        number: quantizeWithTolerance(tolerances, weightCurrency.name, fill),
        currency: weightCurrency,
      );
    } else if (target.pendingCost != null &&
        target.pendingCost!.numberPer == null &&
        target.pendingCost!.numberTotal == null) {
      final unitsAbs = target.units!.number.abs();
      if (unitsAbs == Decimal.zero) {
        return (
          postings: postings,
          errors: [ProcessingError(message: 'Cannot interpolate cost for zero units', location: location)],
        );
      }
      target.pendingCost!.numberPer = (fill.abs() / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28);
      target.pendingCost!.currency ??= weightCurrency;
    }
  }

  final errors = <ProcessingError>[];
  for (final posting in postings) {
    if (posting.units == null) {
      errors.add(ProcessingError(message: 'Transaction has incomplete elements', location: location));
      continue;
    }
    if (posting.pendingCost != null) {
      final cost = posting.pendingCost!.toCost(posting.units!.number.abs());
      if (cost == null) {
        errors.add(ProcessingError(message: 'Transaction has incomplete elements', location: location));
        continue;
      }
      posting.cost = cost;
      posting.pendingCost = null;
    }
  }
  return (postings: postings, errors: errors);
}

void fillResidualPostings(List<MutablePosting> postings, Account roundingAccount) {
  final residual = <String, Decimal>{};
  for (final posting in postings) {
    if (posting.units == null) continue;
    final weight = postingWeight(posting);
    residual.update(weight.currency.name, (value) => value + weight.number, ifAbsent: () => weight.number);
  }
  for (final entry in residual.entries) {
    if (entry.value == Decimal.zero) continue;
    postings.add(
      MutablePosting(
        origin: const Origin.generated(),
        meta: const Meta(),
        account: roundingAccount,
        units: Amount(
          number: -entry.value,
          currency: Currency(name: entry.key),
        ),
      ),
    );
  }
}
