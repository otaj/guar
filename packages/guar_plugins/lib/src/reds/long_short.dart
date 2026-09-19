// Rebook capital gains into short-term and long-term accounts (IRS holding period).

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

BookPluginResult longShort(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null || parsed.map!.isEmpty) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final MapEntry<Object?, Object?> first = parsed.map!.entries.first;
  if (first.key is! String || first.value is! List) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final List<Object?> spec = first.value! as List<Object?>;
  if (spec.length < 3 || spec.any((Object? item) => item is! String)) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final RegExp match = pythonRegExp(first.key! as String);
  final String needle = spec[0]! as String;
  final String shortRepl = spec[1]! as String;
  final String longRepl = spec[2]! as String;
  final Set<String> newAccounts = <String>{};
  final List<Directive> out = <Directive>[];

  for (final Directive directive in directives) {
    final Transaction? transaction = transactionOf(directive);
    if (transaction == null || !_interesting(transaction, match, shortRepl, longRepl)) {
      out.add(directive);
      continue;
    }
    final List<Posting> reductions = <Posting>[
      for (final Posting posting in transaction.postings)
        if (posting.cost != null && posting.units.number != Decimal.zero && posting.price != null) posting,
    ];
    if (reductions.isEmpty) {
      out.add(directive);
      continue;
    }
    Decimal shortGains = Decimal.zero;
    Decimal longGains = Decimal.zero;
    for (final Posting posting in reductions) {
      final Decimal gain = (posting.cost!.number - posting.price!.number) * posting.units.number.abs();
      if (isLongTermHolding(posting.cost!.date, directive.date)) {
        longGains += gain;
      } else {
        shortGains += gain;
      }
    }
    final List<Posting> orig = <Posting>[
      for (final Posting posting in transaction.postings)
        if (match.hasMatch(posting.account.name)) posting,
    ];
    if (orig.isEmpty) {
      out.add(directive);
      continue;
    }
    Decimal origSum = Decimal.zero;
    for (final Posting posting in orig) {
      origSum += posting.units.number;
    }
    final Decimal diff = origSum - (shortGains + longGains);
    final Currency currency = orig.first.units.currency;
    if (diff.abs() >= _inferredTolerance(transaction.postings, currency, options)) {
      final Decimal total = shortGains + longGains;
      if (total != Decimal.zero) {
        shortGains += (shortGains / total).toDecimal(scaleOnInfinitePrecision: 16) * diff;
        longGains += (longGains / total).toDecimal(scaleOnInfinitePrecision: 16) * diff;
      }
    }
    final List<Posting> kept = <Posting>[
      for (final Posting posting in transaction.postings)
        if (!match.hasMatch(posting.account.name)) posting,
    ];
    final Posting template = orig.first;
    if (shortGains != Decimal.zero) {
      final String account = template.account.name.replaceAll(needle, shortRepl);
      newAccounts.add(account);
      kept.add(
        template.copyWith(
          account: rewriteAccount(account, options),
          units: Amount(number: shortGains, currency: currency, scale: template.units.scale),
        ),
      );
    }
    if (longGains != Decimal.zero) {
      final String account = template.account.name.replaceAll(needle, longRepl);
      newAccounts.add(account);
      kept.add(
        template.copyWith(
          account: rewriteAccount(account, options),
          units: Amount(number: longGains, currency: currency, scale: template.units.scale),
        ),
      );
    }
    out.add(replaceTransaction(directive, transaction.copyWith(postings: kept)));
  }
  return (
    directives: <Directive>[...createOpenDirectives(newAccounts, directives, options, info), ...out],
    errors: const <ProcessingError>[],
  );
}

bool _interesting(Transaction transaction, RegExp match, String shortRepl, String longRepl) {
  bool generic = false;
  for (final Posting posting in transaction.postings) {
    if (posting.account.name.contains(shortRepl) || posting.account.name.contains(longRepl)) {
      return false;
    }
    if (match.hasMatch(posting.account.name)) generic = true;
  }
  return generic;
}

Decimal _inferredTolerance(List<Posting> postings, Currency currency, LedgerOptions options) {
  final Decimal multiplier = options.inferredToleranceMultiplier.value;
  Decimal tolerance = Decimal.zero;
  for (final Posting posting in postings) {
    if (posting.units.currency.name != currency.name) continue;
    final int scale = posting.units.scale;
    if (scale <= 0) continue;
    final Decimal candidate = Decimal.one.shift(-scale) * multiplier;
    if (candidate > tolerance) tolerance = candidate;
  }
  return tolerance;
}
