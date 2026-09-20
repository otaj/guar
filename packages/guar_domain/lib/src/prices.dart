// Historical price database built from booked price directives.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/date.dart';
import 'package:guar_domain/src/directive.dart';
import 'package:guar_domain/src/inventory.dart';
import 'package:guar_domain/src/position.dart';
import 'package:guar_domain/src/posting.dart';
import 'package:guar_domain/src/transaction.dart';

part 'prices.freezed.dart';

@freezed
abstract class PricePoint with _$PricePoint {
  const factory PricePoint({required BeanDate date, required Decimal rate}) = _PricePoint;
}

@freezed
abstract class CurrencyPair with _$CurrencyPair {
  const factory CurrencyPair({required Currency base, required Currency quote}) = _CurrencyPair;
}

@freezed
abstract class PriceQuote with _$PriceQuote {
  const factory PriceQuote({required Decimal rate, BeanDate? date}) = _PriceQuote;
}

@freezed
abstract class PriceMap with _$PriceMap {
  const factory PriceMap({
    @Default(<dynamic, dynamic>{}) Map<CurrencyPair, List<PricePoint>> rates,
    @Default(<CurrencyPair>[]) List<CurrencyPair> forwardPairs,
  }) = _PriceMap;
  const PriceMap._();

  factory PriceMap.build(Iterable<Directive> directives) {
    final Map<CurrencyPair, List<PricePoint>> collected = <CurrencyPair, List<PricePoint>>{};
    final Map<Account, Inventory> balances = <Account, Inventory>{};

    void addRate(BeanDate date, Currency base, Amount quote) {
      if (base == quote.currency) {
        return;
      }
      final CurrencyPair pair = CurrencyPair(base: base, quote: quote.currency);
      collected.putIfAbsent(pair, () => <PricePoint>[]).add(PricePoint(date: date, rate: quote.number));
    }

    for (final Directive directive in directives) {
      final DirectiveBody body = directive.body;
      switch (body) {
        case PriceBody(:final Currency currency, :final Amount amount):
          addRate(directive.date, currency, amount);
        case TransactionBody(:final Transaction value):
          for (final Posting posting in value.postings) {
            final InventoryAdd booking = (balances[posting.account] ?? const Inventory()).addPosition(
              Position(units: posting.units, cost: posting.cost),
            );
            balances[posting.account] = booking.inventory;

            if (posting.price != null) {
              addRate(directive.date, posting.units.currency, posting.price!);
            } else if (posting.cost != null && booking.result != MatchResult.reduced) {
              addRate(
                directive.date,
                posting.units.currency,
                Amount(number: posting.cost!.number, currency: posting.cost!.currency),
              );
            }
          }
        default:
          break;
      }
    }

    final Set<CurrencyPair> seen = <CurrencyPair>{};
    for (final CurrencyPair pair in collected.keys.toList()) {
      final CurrencyPair inverse = CurrencyPair(base: pair.quote, quote: pair.base);
      if (seen.contains(pair) || seen.contains(inverse)) {
        continue;
      }
      if (!collected.containsKey(inverse)) {
        continue;
      }
      seen
        ..add(pair)
        ..add(inverse);
      final List<PricePoint> forward = collected[pair]!;
      final List<PricePoint> backward = collected[inverse]!;
      final CurrencyPair remove = forward.length < backward.length ? pair : inverse;
      final CurrencyPair keep = remove == pair ? inverse : pair;
      final List<PricePoint> removeList = collected.remove(remove)!;
      collected.putIfAbsent(keep, () => <PricePoint>[]).addAll(<PricePoint>[
        for (final PricePoint point in removeList)
          if (point.rate != Decimal.zero)
            PricePoint(date: point.date, rate: (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28)),
      ]);
    }

    final Map<CurrencyPair, List<PricePoint>> sorted = <CurrencyPair, List<PricePoint>>{};
    for (final MapEntry<CurrencyPair, List<PricePoint>> entry in collected.entries) {
      final Map<BeanDate, PricePoint> byDate = <BeanDate, PricePoint>{};
      for (final PricePoint point in entry.value) {
        byDate[point.date] = point;
      }
      final List<PricePoint> points = byDate.values.toList()
        ..sort((PricePoint a, PricePoint b) => compareBeanDate(a.date, b.date));
      sorted[entry.key] = points;
    }

    final List<CurrencyPair> forwardPairs = List<CurrencyPair>.from(sorted.keys);
    for (final CurrencyPair pair in forwardPairs) {
      final CurrencyPair inverse = CurrencyPair(base: pair.quote, quote: pair.base);
      sorted[inverse] = <PricePoint>[
        for (final PricePoint point in sorted[pair]!)
          if (point.rate != Decimal.zero)
            PricePoint(date: point.date, rate: (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28)),
      ];
    }

    return PriceMap(rates: sorted, forwardPairs: forwardPairs);
  }

  List<PricePoint>? _lookupPrices(CurrencyPair pair) =>
      rates[pair] ?? rates[CurrencyPair(base: pair.quote, quote: pair.base)];

  List<PricePoint> allPrices(CurrencyPair pair) {
    final List<PricePoint>? found = _lookupPrices(pair);
    if (found != null) {
      return found;
    }
    throw StateError('No prices for ${pair.base.name}/${pair.quote.name}');
  }

  PriceQuote? latestPrice(CurrencyPair pair) {
    if (pair.base == pair.quote) {
      return PriceQuote(rate: Decimal.one);
    }
    final List<PricePoint>? prices = _lookupPrices(pair);
    if (prices == null || prices.isEmpty) {
      return null;
    }
    final PricePoint last = prices.last;
    return PriceQuote(date: last.date, rate: last.rate);
  }

  PriceQuote? priceAt(CurrencyPair pair, [BeanDate? date]) {
    if (date == null) {
      return latestPrice(pair);
    }
    if (pair.base == pair.quote) {
      return PriceQuote(rate: Decimal.one);
    }
    final List<PricePoint>? prices = _lookupPrices(pair);
    if (prices == null) {
      return null;
    }
    PricePoint? found;
    for (final PricePoint point in prices) {
      if (compareBeanDate(point.date, date) <= 0) {
        found = point;
      } else {
        break;
      }
    }
    return found == null ? null : PriceQuote(date: found.date, rate: found.rate);
  }

  PriceMap project(Currency fromQuote, Currency toQuote, {Set<Currency>? baseCurrencies}) {
    if (fromQuote == toQuote) {
      return this;
    }
    final Map<CurrencyPair, List<PricePoint>> next = <CurrencyPair, List<PricePoint>>{
      for (final MapEntry<CurrencyPair, List<PricePoint>> entry in rates.entries)
        entry.key: <PricePoint>[...entry.value],
    };
    final CurrencyPair conversionPair = CurrencyPair(base: fromQuote, quote: toQuote);

    for (final MapEntry<CurrencyPair, List<PricePoint>> entry in Map<CurrencyPair, List<PricePoint>>.from(
      rates,
    ).entries) {
      if (entry.key.quote != fromQuote) {
        continue;
      }
      final Currency base = entry.key.base;
      if (baseCurrencies != null && !baseCurrencies.contains(base)) {
        continue;
      }
      final CurrencyPair target = CurrencyPair(base: base, quote: toQuote);
      final Set<BeanDate> existingDates = <BeanDate>{
        for (final PricePoint point in next[target] ?? const <PricePoint>[]) point.date,
      };
      final List<PricePoint> projected = <PricePoint>[];
      for (final PricePoint point in entry.value) {
        final PriceQuote? rate = priceAt(conversionPair, point.date);
        if (rate == null) {
          continue;
        }
        if (rate.date != null && existingDates.contains(rate.date)) {
          continue;
        }
        projected.add(PricePoint(date: point.date, rate: point.rate * rate.rate));
      }
      if (projected.isEmpty) {
        continue;
      }
      final List<PricePoint> merged = <PricePoint>[...(next[target] ?? const <PricePoint>[]), ...projected]
        ..sort((PricePoint a, PricePoint b) => compareBeanDate(a.date, b.date));
      next[target] = merged;
      final CurrencyPair inverted = CurrencyPair(base: toQuote, quote: base);
      next[inverted] = <PricePoint>[
        ...(next[inverted] ?? const <PricePoint>[]),
        for (final PricePoint point in projected)
          PricePoint(
            date: point.date,
            rate: point.rate == Decimal.zero
                ? Decimal.zero
                : (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28),
          ),
      ]..sort((PricePoint a, PricePoint b) => compareBeanDate(a.date, b.date));
    }

    return PriceMap(rates: next, forwardPairs: forwardPairs);
  }
}
