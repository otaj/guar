// Cross-check priced lot sales against the non-income proceeds legs.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'helpers.dart';

final Decimal _extraToleranceMultiplier = Decimal.fromInt(2);

BookPluginResult validateSellGains(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final errors = <ProcessingError>[];
  for (final directive in directives) {
    if (directive.body case TransactionBody(:final value)) {
      final atCost = [
        for (final posting in value.postings)
          if (posting.cost != null) posting,
      ];
      if (atCost.isEmpty || atCost.any((posting) => posting.price == null)) continue;

      final price = <String, Decimal>{};
      final proceeds = <String, Decimal>{};
      for (final posting in value.postings) {
        if (posting.cost != null) {
          final unitPrice = posting.price!;
          _accumulate(price, unitPrice.currency.name, unitPrice.number * -posting.units.number);
        } else if (_isProceedAccount(posting.account)) {
          final weight = _postingWeight(posting);
          _accumulate(proceeds, weight.currency.name, weight.number);
        }
      }

      final tolerances = _inferTolerances(value.postings, options);
      final remaining = Map<String, Decimal>.from(proceeds);
      var invalid = false;
      for (final entry in price.entries) {
        final tolerance = (tolerances[entry.key] ?? Decimal.zero) * _extraToleranceMultiplier;
        final counterpart = remaining.remove(entry.key) ?? Decimal.zero;
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
  final cost = posting.cost;
  if (cost != null) {
    return Amount(number: posting.units.number * cost.number, currency: cost.currency);
  }
  final price = posting.price;
  if (price != null) {
    return Amount(number: posting.units.number * price.number, currency: price.currency);
  }
  return posting.units;
}

Map<String, Decimal> _inferTolerances(List<Posting> postings, LedgerOptions options) {
  final multiplier = options.toleranceMultiplier ?? Decimal.parse('0.5');
  final seen = <String>{};
  for (final posting in postings) {
    seen.add(posting.units.currency.name);
    final cost = posting.cost;
    if (cost != null) seen.add(cost.currency.name);
    final price = posting.price;
    if (price != null) seen.add(price.currency.name);
  }

  final tolerances = <String, Decimal>{};
  var fallback = Decimal.zero;
  for (final preset in options.inferredToleranceDefault) {
    switch (preset.key) {
      case CurrencyKeyAll():
        fallback = preset.value;
      case CurrencyKeyCurrency(:final value):
        if (seen.contains(value.name)) {
          tolerances[value.name] = preset.value;
        }
    }
  }

  for (final posting in postings) {
    final scale = posting.units.number.scale;
    if (scale <= 0) continue;
    final tolerance = Decimal.parse('1e-$scale') * multiplier;
    final currency = posting.units.currency.name;
    final existing = tolerances[currency];
    tolerances[currency] = existing == null || tolerance > existing ? tolerance : existing;
  }

  if (fallback != Decimal.zero) {
    for (final currency in seen) {
      tolerances.putIfAbsent(currency, () => fallback);
    }
  }
  return tolerances;
}

Map<String, Decimal> _difference(Map<String, Decimal> price, Map<String, Decimal> proceeds) {
  final out = Map<String, Decimal>.from(price);
  for (final entry in proceeds.entries) {
    out[entry.key] = (out[entry.key] ?? Decimal.zero) - entry.value;
  }
  return out;
}

String _render(Map<String, Decimal> totals) {
  final currencies = totals.keys.toList()..sort();
  return '(${[for (final currency in currencies)
    if (totals[currency] != Decimal.zero) '${totals[currency]} $currency'].join(', ')})';
}
