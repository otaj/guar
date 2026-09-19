// Prorate box-spread capital losses across calendar years.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

BookPluginResult boxAccrual(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) => (
  directives: <Directive>[for (final Directive directive in directives) _accrue(directive)],
  errors: const <ProcessingError>[],
);

Directive _accrue(Directive directive) {
  final Transaction? transaction = transactionOf(directive);
  if (transaction == null) return directive;
  final BeanDate? expiry = metaDate(directive.meta, 'synthetic_loan_expiry');
  if (expiry == null) return directive;
  final List<int> losses = <int>[
    for (int i = 0; i < transaction.postings.length; i++)
      if (transaction.postings[i].account.name.endsWith(':Capital-Losses')) i,
  ];
  if (losses.length != 1) return directive;
  final Posting loss = transaction.postings[losses.single];
  final BeanDate start = directive.date;
  if (start.year == expiry.year) return directive;
  final int totalDays = daysInclusive(start, expiry);
  if (totalDays <= 0) return directive;

  final List<({int days, BeanDate end})> fractions = <({int days, BeanDate end})>[];
  for (int year = start.year; year <= expiry.year; year++) {
    final BeanDate yearStart = BeanDate(year: year, month: 1, day: 1);
    final BeanDate yearEnd = BeanDate(year: year, month: 12, day: 31);
    final BeanDate segStart = compareBeanDate(start, yearStart) > 0 ? start : yearStart;
    final BeanDate segEnd = compareBeanDate(expiry, yearEnd) < 0 ? expiry : yearEnd;
    final int segDays = daysInclusive(segStart, segEnd);
    if (segDays <= 0) continue;
    fractions.add((days: segDays, end: segEnd));
  }
  if (fractions.isEmpty) return directive;

  final Decimal totalLoss = loss.units.number;
  final List<Posting> splits = <Posting>[];
  Decimal roundedSum = Decimal.zero;
  for (int i = 0; i < fractions.length; i++) {
    Decimal segAmt = (totalLoss * Decimal.fromInt(fractions[i].days) / Decimal.fromInt(totalDays)).toDecimal(
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
      postings: <Posting>[
        for (int i = 0; i < transaction.postings.length; i++)
          if (i != losses.single) transaction.postings[i],
        ...splits,
      ],
    ),
  );
}
