// Require a Commodity directive for every commodity the ledger uses.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'config_literal.dart';
import 'helpers.dart';

const _priceContext = 'Price Directive Context';
const _metadataContext = 'Metadata Value Context';
const _anonymous = {_priceContext, _metadataContext};

BookPluginResult validateCommodityDirectives(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final errors = <ProcessingError>[];
  var configObject = const <Object?, Object?>{};
  if (config != null && config.isNotEmpty) {
    final parsed = parseConfigLiteral(config);
    final value = parsed.value;
    if (parsed.error != null || value is! Map<Object?, Object?>) {
      return (
        directives: directives,
        errors: [
          ProcessingError(
            message: 'Invalid configuration for check_commodity plugin; skipping.',
            location: nowhereLocation('<commodity_attr>'),
          ),
        ],
      );
    }
    configObject = value;
  }

  final ignore = <(RegExp, RegExp)>[];
  for (final entry in configObject.entries) {
    final patterns = <RegExp>[];
    for (final pattern in ['${entry.key}', '${entry.value}']) {
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

  final declared = <String>{};
  final occurrences = <(String, String)>{};
  for (final directive in directives) {
    switch (directive.body) {
      case CommodityBody(:final currency):
        declared.add(currency.name);
      case OpenBody(:final account, :final currencies):
        for (final currency in currencies) {
          occurrences.add((account.name, currency.name));
        }
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          occurrences.add((posting.account.name, posting.units.currency.name));
          final cost = posting.cost;
          if (cost != null) {
            occurrences.add((posting.account.name, cost.currency.name));
          }
          final price = posting.price;
          if (price != null) {
            occurrences.add((posting.account.name, price.currency.name));
          }
        }
      case BalanceBody(:final account, :final amount):
        occurrences.add((account.name, amount.currency.name));
      case PriceBody(:final currency, :final amount):
        occurrences.add((_priceContext, currency.name));
        occurrences.add((_priceContext, amount.currency.name));
      default:
        break;
    }
  }

  final sorted = occurrences.toList()
    ..sort((a, b) {
      final byContext = a.$1.compareTo(b.$1);
      return byContext != 0 ? byContext : a.$2.compareTo(b.$2);
    });

  final issued = <String>{};
  final ignored = <String>{};
  final anonymous = <(String, String)>[];
  for (final (context, currency) in sorted) {
    if (_anonymous.contains(context)) {
      anonymous.add((context, currency));
      continue;
    }
    if (declared.contains(currency) || issued.contains(currency)) continue;
    if (ignore.any((pair) => pair.$1.matchAsPrefix(context) != null && pair.$2.matchAsPrefix(currency) != null)) {
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

  for (final (context, currency) in anonymous) {
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
