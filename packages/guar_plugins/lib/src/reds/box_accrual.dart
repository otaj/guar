// Prorate box-spread capital losses across calendar years.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

BookPluginResult boxAccrual(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  return (directives: [for (final directive in directives) _accrue(directive)], errors: const []);
}

Directive _accrue(Directive directive) {
  final transaction = transactionOf(directive);
  if (transaction == null) return directive;
  final expiry = metaDate(directive.meta, 'synthetic_loan_expiry');
  if (expiry == null) return directive;
  final losses = [
    for (var i = 0; i < transaction.postings.length; i++)
      if (transaction.postings[i].account.name.endsWith(':Capital-Losses')) i,
  ];
  if (losses.length != 1) return directive;
  final loss = transaction.postings[losses.single];
  final start = directive.date;
  if (start.year == expiry.year) return directive;
  final totalDays = daysInclusive(start, expiry);
  if (totalDays <= 0) return directive;

  final fractions = <({int days, BeanDate end})>[];
  for (var year = start.year; year <= expiry.year; year++) {
    final yearStart = BeanDate(year: year, month: 1, day: 1);
    final yearEnd = BeanDate(year: year, month: 12, day: 31);
    final segStart = compareBeanDate(start, yearStart) > 0 ? start : yearStart;
    final segEnd = compareBeanDate(expiry, yearEnd) < 0 ? expiry : yearEnd;
    final segDays = daysInclusive(segStart, segEnd);
    if (segDays <= 0) continue;
    fractions.add((days: segDays, end: segEnd));
  }
  if (fractions.isEmpty) return directive;

  final totalLoss = loss.units.number;
  final splits = <Posting>[];
  var roundedSum = Decimal.zero;
  for (var i = 0; i < fractions.length; i++) {
    var segAmt = (totalLoss * Decimal.fromInt(fractions[i].days) / Decimal.fromInt(totalDays)).toDecimal(
      scaleOnInfinitePrecision: 16,
    );
    if (i < fractions.length - 1) {
      segAmt = segAmt.round(scale: 2);
      roundedSum += segAmt;
    } else {
      segAmt = (totalLoss - roundedSum).round(scale: 2);
    }
    splits.add(
      loss.copyWith(
        units: Amount(number: segAmt, currency: loss.units.currency, scale: 2),
        cost: null,
        price: null,
        meta: metaWith(const Meta(), 'effective_date', MetaValue.date(fractions[i].end)),
      ),
    );
  }

  return replaceTransaction(
    directive,
    transaction.copyWith(
      postings: [
        for (var i = 0; i < transaction.postings.length; i++)
          if (i != losses.single) transaction.postings[i],
        ...splits,
      ],
    ),
  );
}
