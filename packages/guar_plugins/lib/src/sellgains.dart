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
          final Amount weight = postingWeightOf(posting.units, cost: posting.cost, price: posting.price);
          _accumulate(proceeds, weight.currency.name, weight.number);
        }
      }

      final InferredTolerances tolerances = inferBookedTolerances(value.postings, options);
      final Map<String, Decimal> remaining = Map<String, Decimal>.from(proceeds);
      bool invalid = false;
      for (final MapEntry<String, Decimal> entry in price.entries) {
        final Decimal tolerance = tolerances[entry.key] * _extraToleranceMultiplier;
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
