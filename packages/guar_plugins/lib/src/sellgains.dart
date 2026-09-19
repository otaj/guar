// Cross-check priced lot sales against the non-income proceeds legs.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

final Decimal _extraToleranceMultiplier = Decimal.fromInt(2);

BookPluginResult validateSellGains(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final List<ProcessingError> errors = <ProcessingError>[];
  for (final Directive directive in directives) {
    if (directive.body case TransactionBody(:final Transaction value)) {
      final List<Posting> atCost = <Posting>[
        for (final Posting posting in value.postings)
          if (posting.cost != null) posting,
      ];
      if (atCost.isEmpty || atCost.any((Posting posting) => posting.price == null)) continue;

      final Map<String, Decimal> price = <String, Decimal>{};
      final Map<String, Decimal> proceeds = <String, Decimal>{};
      for (final Posting posting in value.postings) {
        if (posting.cost != null) {
          final Amount unitPrice = posting.price!;
          _accumulate(price, unitPrice.currency.name, unitPrice.number * -posting.units.number);
        } else if (_isProceedAccount(posting.account)) {
          final Amount weight = _postingWeight(posting);
          _accumulate(proceeds, weight.currency.name, weight.number);
        }
      }

      final Map<String, Decimal> tolerances = _inferTolerances(value.postings, options);
      final Map<String, Decimal> remaining = Map<String, Decimal>.from(proceeds);
      bool invalid = false;
      for (final MapEntry<String, Decimal> entry in price.entries) {
        final Decimal tolerance = (tolerances[entry.key] ?? Decimal.zero) * _extraToleranceMultiplier;
        final Decimal counterpart = remaining.remove(entry.key) ?? Decimal.zero;
        if ((entry.value - counterpart).abs() > tolerance) {
          invalid = true;
          break;
        }
      }

      if (invalid || remaining.isNotEmpty) {
        errors.add(
          ProcessingError(
            message:
                'Invalid price vs. proceeds/gains: ${_render(price)} vs. ${_render(proceeds)}; '
                'difference: ${_render(_difference(price, proceeds))}',
            location: directiveLocation(directive),
          ),
        );
      }
    }
  }
  return (directives: directives, errors: errors);
}

void _accumulate(Map<String, Decimal> totals, String currency, Decimal number) {
  totals[currency] = (totals[currency] ?? Decimal.zero) + number;
}

bool _isProceedAccount(Account account) => switch (account.type) {
  AccountType.assets || AccountType.liabilities || AccountType.equity || AccountType.expenses => true,
  AccountType.income => false,
};

Amount _postingWeight(Posting posting) {
  final Cost? cost = posting.cost;
  if (cost != null) {
    return Amount(number: posting.units.number * cost.number, currency: cost.currency);
  }
  final Amount? price = posting.price;
  if (price != null) {
    return Amount(number: posting.units.number * price.number, currency: price.currency);
  }
  return posting.units;
}

Map<String, Decimal> _inferTolerances(List<Posting> postings, LedgerOptions options) {
  final Decimal multiplier = options.inferredToleranceMultiplier.value;
  final Set<String> seen = <String>{};
  for (final Posting posting in postings) {
    seen.add(posting.units.currency.name);
    final Cost? cost = posting.cost;
    if (cost != null) seen.add(cost.currency.name);
    final Amount? price = posting.price;
    if (price != null) seen.add(price.currency.name);
  }

  final Map<String, Decimal> tolerances = <String, Decimal>{};
  Decimal fallback = Decimal.zero;
  for (final InferredTolerance preset in options.inferredToleranceDefault) {
    switch (preset.key) {
      case CurrencyKeyAll():
        fallback = preset.value;
      case CurrencyKeyCurrency(:final Currency value):
        if (seen.contains(value.name)) {
          tolerances[value.name] = preset.value;
        }
    }
  }

  for (final Posting posting in postings) {
    final int scale = posting.units.scale;
    if (scale <= 0) continue;
    final Decimal tolerance = Decimal.parse('1e-$scale') * multiplier;
    final String currency = posting.units.currency.name;
    final Decimal? existing = tolerances[currency];
    tolerances[currency] = existing == null || tolerance > existing ? tolerance : existing;
  }

  if (fallback != Decimal.zero) {
    for (final String currency in seen) {
      tolerances.putIfAbsent(currency, () => fallback);
    }
  }
  return tolerances;
}

Map<String, Decimal> _difference(Map<String, Decimal> price, Map<String, Decimal> proceeds) {
  final Map<String, Decimal> out = Map<String, Decimal>.from(price);
  for (final MapEntry<String, Decimal> entry in proceeds.entries) {
    out[entry.key] = (out[entry.key] ?? Decimal.zero) - entry.value;
  }
  return out;
}

String _render(Map<String, Decimal> totals) {
  final List<String> currencies = totals.keys.toList()..sort();
  return '(${<String>[for (final String currency in currencies)
    if (totals[currency] != Decimal.zero) '${totals[currency]} $currency'].join(', ')})';
}
