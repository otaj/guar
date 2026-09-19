// Require a Commodity directive for every commodity the ledger uses.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

const String _priceContext = 'Price Directive Context';
const String _metadataContext = 'Metadata Value Context';
const Set<String> _anonymous = <String>{_priceContext, _metadataContext};

BookPluginResult validateCommodityDirectives(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final List<ProcessingError> errors = <ProcessingError>[];
  Map<Object?, Object?> configObject = const <Object?, Object?>{};
  if (config != null && config.isNotEmpty) {
    final ConfigLiteral parsed = parseConfigLiteral(config);
    final Object? value = parsed.value;
    if (parsed.error != null || value is! Map<Object?, Object?>) {
      return (
        directives: directives,
        errors: <ProcessingError>[
          ProcessingError(
            message: 'Invalid configuration for check_commodity plugin; skipping.',
            location: nowhereLocation('<commodity_attr>'),
          ),
        ],
      );
    }
    configObject = value;
  }

  final List<(RegExp, RegExp)> ignore = <(RegExp, RegExp)>[];
  for (final MapEntry<Object?, Object?> entry in configObject.entries) {
    final List<RegExp> patterns = <RegExp>[];
    for (final String pattern in <String>['${entry.key}', '${entry.value}']) {
      try {
        patterns.add(RegExp(pattern));
      } on FormatException {
        errors.add(
          ProcessingError(
            message: "Invalid regexp: '${entry.value}' for ${entry.key}",
            location: nowhereLocation('<check_commodity>'),
          ),
        );
      }
    }
    if (patterns.length == 2) {
      ignore.add((patterns[0], patterns[1]));
    }
  }

  final Set<String> declared = <String>{};
  final Set<(String, String)> occurrences = <(String, String)>{};
  for (final Directive directive in directives) {
    switch (directive.body) {
      case CommodityBody(:final Currency currency):
        declared.add(currency.name);
      case OpenBody(:final Account account, :final List<Currency> currencies):
        for (final Currency currency in currencies) {
          occurrences.add((account.name, currency.name));
        }
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          occurrences.add((posting.account.name, posting.units.currency.name));
          final Cost? cost = posting.cost;
          if (cost != null) {
            occurrences.add((posting.account.name, cost.currency.name));
          }
          final Amount? price = posting.price;
          if (price != null) {
            occurrences.add((posting.account.name, price.currency.name));
          }
        }
      case BalanceBody(:final Account account, :final Amount amount):
        occurrences.add((account.name, amount.currency.name));
      case PriceBody(:final Currency currency, :final Amount amount):
        occurrences.add((_priceContext, currency.name));
        occurrences.add((_priceContext, amount.currency.name));
      default:
        break;
    }
  }

  final List<(String, String)> sorted = occurrences.toList()
    ..sort(((String, String) a, (String, String) b) {
      final int byContext = a.$1.compareTo(b.$1);
      return byContext != 0 ? byContext : a.$2.compareTo(b.$2);
    });

  final Set<String> issued = <String>{};
  final Set<String> ignored = <String>{};
  final List<(String, String)> anonymous = <(String, String)>[];
  for (final (String context, String currency) in sorted) {
    if (_anonymous.contains(context)) {
      anonymous.add((context, currency));
      continue;
    }
    if (declared.contains(currency) || issued.contains(currency)) continue;
    if (ignore.any(
      ((RegExp, RegExp) pair) => pair.$1.matchAsPrefix(context) != null && pair.$2.matchAsPrefix(currency) != null,
    )) {
      ignored.add(currency);
      continue;
    }
    errors.add(
      ProcessingError(
        message: "Missing Commodity directive for '$currency' in '$context'",
        location: nowhereLocation('<check_commodity>'),
      ),
    );
    issued.add(currency);
  }

  for (final (String context, String currency) in anonymous) {
    if (declared.contains(currency) || issued.contains(currency) || ignored.contains(currency)) continue;
    errors.add(
      ProcessingError(
        message: "Missing Commodity directive for '$currency' in '$context'",
        location: nowhereLocation('<check_commodity>'),
      ),
    );
  }
  return (directives: directives, errors: errors);
}
