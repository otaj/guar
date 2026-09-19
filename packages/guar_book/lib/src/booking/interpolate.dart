// Interpolate a currency group and convert remaining CostSpecs to Costs.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

class MutablePosting {
  MutablePosting({
    required this.origin,
    required this.meta,
    required this.account,
    this.flag,
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
    final Amount? resolvedUnits = units;
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
  PendingCost({required this.date, this.numberPer, this.numberTotal, this.currency, this.label});

  Decimal? numberPer;
  Decimal? numberTotal;
  Currency? currency;
  final BeanDate date;
  final String? label;

  bool get isComplete => numberPer != null || numberTotal != null;

  Cost? toCost(Decimal unitsAbs) {
    final Currency? resolvedCurrency = currency;
    if (resolvedCurrency == null) {
      return null;
    }
    if (numberTotal != null) {
      Decimal total = numberTotal!;
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
  final Amount units = posting.units!;
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
const int _maxToleranceDigits = 5;

InferredTolerances inferPostingTolerances(
  List<Posting> postings,
  LedgerOptions options, {
  ToleranceMode mode = ToleranceMode.max,
}) => inferTolerances(
  <MutablePosting>[
    for (final Posting posting in postings)
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

InferredTolerances inferTolerances(
  List<MutablePosting> postings,
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
  for (final MutablePosting posting in postings) {
    final Amount? units = posting.units;
    if (units != null) seen.add(units.currency.name);
    final Cost? cost = posting.cost;
    if (cost != null) seen.add(cost.currency.name);
    final PendingCost? pending = posting.pendingCost;
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
  for (final MutablePosting posting in postings) {
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
    final PendingCost? pending = posting.pendingCost;
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

Decimal quantizeWithTolerance(InferredTolerances tolerances, String currency, Decimal number) {
  final Decimal tolerance = tolerances[currency];
  if (tolerance == Decimal.zero) return number;
  final Decimal quantum = tolerance * Decimal.fromInt(2);
  if (_coefficientDigits(quantum) >= _maxToleranceDigits) return number;
  if (quantum == Decimal.zero) return number;
  final BigInt rounded = (number / quantum).round();
  return quantum * Decimal.fromBigInt(rounded);
}

Decimal _minDecimal(Decimal left, Decimal right) => left < right ? left : right;

int _coefficientDigits(Decimal number) {
  final String digits = number.abs().toString().replaceAll('.', '').replaceFirst(RegExp('^0+'), '');
  return digits.isEmpty ? 1 : digits.length;
}

({List<MutablePosting> postings, List<ProcessingError> errors}) interpolateGroup(
  List<MutablePosting> postings,
  BeanLocation location,
  InferredTolerances tolerances,
) {
  final List<int> missingUnits = <int>[];
  final List<int> missingCost = <int>[];
  for (int i = 0; i < postings.length; i++) {
    final MutablePosting posting = postings[i];
    if (posting.units == null) {
      missingUnits.add(i);
    } else if (posting.pendingCost != null && !posting.pendingCost!.isComplete) {
      missingCost.add(i);
    }
  }

  if (missingUnits.length > 1 || missingCost.length > 1) {
    return (
      postings: postings,
      errors: <ProcessingError>[
        ProcessingError(message: 'Too many missing numbers for currency group', location: location),
      ],
    );
  }

  if (missingUnits.length == 1) {
    final int index = missingUnits.single;
    final Map<String, Decimal> residual = <String, Decimal>{};
    for (int i = 0; i < postings.length; i++) {
      if (i == index) continue;
      final MutablePosting posting = postings[i];
      if (posting.units == null) continue;
      final Amount weight = postingWeight(posting);
      residual.update(weight.currency.name, (Decimal value) => value + weight.number, ifAbsent: () => weight.number);
    }
    final List<MapEntry<String, Decimal>> nonzero = <MapEntry<String, Decimal>>[
      for (final MapEntry<String, Decimal> entry in residual.entries)
        if (entry.value != Decimal.zero) entry,
    ];
    if (nonzero.length == 1) {
      final Decimal fill = -nonzero.single.value;
      final Currency currency = Currency(name: nonzero.single.key);
      postings[index].units = Amount(
        number: quantizeWithTolerance(tolerances, currency.name, fill),
        currency: currency,
      );
    }
  }

  if (missingCost.length == 1) {
    final int index = missingCost.single;
    final MutablePosting target = postings[index];
    Decimal residual = Decimal.zero;
    Currency? residualCurrency = target.pendingCost?.currency;
    for (int i = 0; i < postings.length; i++) {
      if (i == index) continue;
      final MutablePosting posting = postings[i];
      if (posting.units == null) continue;
      final Amount weight = postingWeight(posting);
      if (residualCurrency != null && weight.currency != residualCurrency) {
        continue;
      }
      residualCurrency ??= weight.currency;
      if (weight.currency != residualCurrency) {
        continue;
      }
      residual += weight.number;
    }
    final Decimal fill = -residual;
    final Decimal unitsAbs = target.units!.number.abs();
    if (unitsAbs == Decimal.zero) {
      return (
        postings: postings,
        errors: <ProcessingError>[
          ProcessingError(message: 'Cannot interpolate cost for zero units', location: location),
        ],
      );
    }
    target.pendingCost!.numberPer = (fill.abs() / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28);
    target.pendingCost!.currency ??= residualCurrency;
  }

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final MutablePosting posting in postings) {
    if (posting.units == null) {
      errors.add(ProcessingError(message: 'Transaction has incomplete elements', location: location));
      continue;
    }
    if (posting.pendingCost != null) {
      final Cost? cost = posting.pendingCost!.toCost(posting.units!.number.abs());
      if (cost == null) {
        errors.add(ProcessingError(message: 'Transaction has incomplete elements', location: location));
        continue;
      }
      posting
        ..cost = cost
        ..pendingCost = null;
    }
  }
  return (postings: postings, errors: errors);
}

void fillResidualPostings(List<MutablePosting> postings, Account roundingAccount) {
  final Map<String, Decimal> residual = <String, Decimal>{};
  for (final MutablePosting posting in postings) {
    if (posting.units == null) continue;
    final Amount weight = postingWeight(posting);
    residual.update(weight.currency.name, (Decimal value) => value + weight.number, ifAbsent: () => weight.number);
  }
  for (final MapEntry<String, Decimal> entry in residual.entries) {
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
