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
  PendingCost({this.numberPer, this.numberTotal, required this.currency, required this.date, this.label});

  Decimal? numberPer;
  Decimal? numberTotal;
  final Currency currency;
  final BeanDate date;
  final String? label;

  bool get isComplete => numberPer != null || numberTotal != null;

  Cost? toCost(Decimal unitsAbs) {
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
        currency: currency,
        date: date,
        label: label,
      );
    }
    if (numberPer == null) {
      return null;
    }
    return Cost(number: numberPer!, currency: currency, date: date, label: label);
  }
}

Amount postingWeight(MutablePosting posting) {
  final units = posting.units!;
  if (posting.cost != null) {
    return Amount(number: units.number * posting.cost!.number, currency: posting.cost!.currency);
  }
  if (posting.pendingCost != null && posting.pendingCost!.numberPer != null) {
    return Amount(number: units.number * posting.pendingCost!.numberPer!, currency: posting.pendingCost!.currency);
  }
  if (posting.price != null) {
    return Amount(number: units.number * posting.price!.number, currency: posting.price!.currency);
  }
  return units;
}

({List<MutablePosting> postings, List<ProcessingError> errors}) interpolateGroup(
  List<MutablePosting> postings,
  Currency weightCurrency,
  BeanLocation location,
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
      target.units = Amount(number: fill, currency: weightCurrency);
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
