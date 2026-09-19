// Rebook capital gains into short-term and long-term accounts (IRS holding period).

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

BookPluginResult longShort(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final parsed = parseConfigMap(config);
  if (parsed.error != null || parsed.map!.isEmpty) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final first = parsed.map!.entries.first;
  if (first.key is! String || first.value is! List) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final spec = first.value! as List<Object?>;
  if (spec.length < 3 || spec.any((item) => item is! String)) {
    return configError(directives, 'Invalid configuration for long_short plugin; skipping.');
  }
  final match = pythonRegExp(first.key! as String);
  final needle = spec[0]! as String;
  final shortRepl = spec[1]! as String;
  final longRepl = spec[2]! as String;
  final newAccounts = <String>{};
  final out = <Directive>[];

  for (final directive in directives) {
    final transaction = transactionOf(directive);
    if (transaction == null || !_interesting(transaction, match, shortRepl, longRepl)) {
      out.add(directive);
      continue;
    }
    final reductions = [
      for (final posting in transaction.postings)
        if (posting.cost != null && posting.units.number != Decimal.zero && posting.price != null) posting,
    ];
    if (reductions.isEmpty) {
      out.add(directive);
      continue;
    }
    var shortGains = Decimal.zero;
    var longGains = Decimal.zero;
    for (final posting in reductions) {
      final gain = (posting.cost!.number - posting.price!.number) * posting.units.number.abs();
      if (isLongTermHolding(posting.cost!.date, directive.date)) {
        longGains += gain;
      } else {
        shortGains += gain;
      }
    }
    final orig = [
      for (final posting in transaction.postings)
        if (match.hasMatch(posting.account.name)) posting,
    ];
    if (orig.isEmpty) {
      out.add(directive);
      continue;
    }
    var origSum = Decimal.zero;
    for (final posting in orig) {
      origSum += posting.units.number;
    }
    final diff = origSum - (shortGains + longGains);
    final currency = orig.first.units.currency;
    if (diff.abs() >= _inferredTolerance(transaction.postings, currency, options)) {
      final total = shortGains + longGains;
      if (total != Decimal.zero) {
        shortGains += (shortGains / total).toDecimal(scaleOnInfinitePrecision: 16) * diff;
        longGains += (longGains / total).toDecimal(scaleOnInfinitePrecision: 16) * diff;
      }
    }
    final kept = [
      for (final posting in transaction.postings)
        if (!match.hasMatch(posting.account.name)) posting,
    ];
    final template = orig.first;
    if (shortGains != Decimal.zero) {
      final account = template.account.name.replaceAll(needle, shortRepl);
      newAccounts.add(account);
      kept.add(
        template.copyWith(
          account: rewriteAccount(account, options),
          units: Amount(number: shortGains, currency: currency, scale: template.units.scale),
        ),
      );
    }
    if (longGains != Decimal.zero) {
      final account = template.account.name.replaceAll(needle, longRepl);
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
  return (directives: [...createOpenDirectives(newAccounts, directives, options, info), ...out], errors: const []);
}

bool _interesting(Transaction transaction, RegExp match, String shortRepl, String longRepl) {
  var generic = false;
  for (final posting in transaction.postings) {
    if (posting.account.name.contains(shortRepl) || posting.account.name.contains(longRepl)) {
      return false;
    }
    if (match.hasMatch(posting.account.name)) generic = true;
  }
  return generic;
}

Decimal _inferredTolerance(List<Posting> postings, Currency currency, LedgerOptions options) {
  final multiplier = options.inferredToleranceMultiplier.value;
  var tolerance = Decimal.zero;
  for (final posting in postings) {
    if (posting.units.currency.name != currency.name) continue;
    final scale = posting.units.scale;
    if (scale <= 0) continue;
    final candidate = Decimal.one.shift(-scale) * multiplier;
    if (candidate > tolerance) tolerance = candidate;
  }
  return tolerance;
}
