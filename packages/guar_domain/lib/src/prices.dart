// Historical price database built from booked price directives.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'date.dart';
import 'directive.dart';
import 'inventory.dart';
import 'position.dart';

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
  const factory PriceQuote({BeanDate? date, required Decimal rate}) = _PriceQuote;
}

@freezed
abstract class PriceMap with _$PriceMap {
  const PriceMap._();

  const factory PriceMap({
    @Default({}) Map<CurrencyPair, List<PricePoint>> rates,
    @Default([]) List<CurrencyPair> forwardPairs,
  }) = _PriceMap;

  factory PriceMap.build(Iterable<Directive> directives) {
    final collected = <CurrencyPair, List<PricePoint>>{};
    final balances = <Account, Inventory>{};

    void addRate(BeanDate date, Currency base, Amount quote) {
      if (base == quote.currency) {
        return;
      }
      final pair = CurrencyPair(base: base, quote: quote.currency);
      collected.putIfAbsent(pair, () => []).add(PricePoint(date: date, rate: quote.number));
    }

    for (final directive in directives) {
      final body = directive.body;
      switch (body) {
        case PriceBody(:final currency, :final amount):
          addRate(directive.date, currency, amount);
        case TransactionBody(:final value):
          for (final posting in value.postings) {
            final booking = (balances[posting.account] ?? const Inventory()).addPosition(
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

    final seen = <CurrencyPair>{};
    for (final pair in collected.keys.toList()) {
      final inverse = CurrencyPair(base: pair.quote, quote: pair.base);
      if (seen.contains(pair) || seen.contains(inverse)) {
        continue;
      }
      if (!collected.containsKey(inverse)) {
        continue;
      }
      seen
        ..add(pair)
        ..add(inverse);
      final forward = collected[pair]!;
      final backward = collected[inverse]!;
      final remove = forward.length < backward.length ? pair : inverse;
      final keep = remove == pair ? inverse : pair;
      final removeList = collected.remove(remove)!;
      collected.putIfAbsent(keep, () => []).addAll([
        for (final point in removeList)
          if (point.rate != Decimal.zero)
            PricePoint(date: point.date, rate: (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28)),
      ]);
    }

    final sorted = <CurrencyPair, List<PricePoint>>{};
    for (final entry in collected.entries) {
      final byDate = <BeanDate, PricePoint>{};
      for (final point in entry.value) {
        byDate[point.date] = point;
      }
      final points = byDate.values.toList()..sort((a, b) => compareBeanDate(a.date, b.date));
      sorted[entry.key] = points;
    }

    final forwardPairs = List<CurrencyPair>.from(sorted.keys);
    for (final pair in forwardPairs) {
      final inverse = CurrencyPair(base: pair.quote, quote: pair.base);
      sorted[inverse] = [
        for (final point in sorted[pair]!)
          if (point.rate != Decimal.zero)
            PricePoint(date: point.date, rate: (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28)),
      ];
    }

    return PriceMap(rates: sorted, forwardPairs: forwardPairs);
  }

  List<PricePoint> allPrices(CurrencyPair pair) {
    final direct = rates[pair];
    if (direct != null) {
      return direct;
    }
    final inverse = rates[CurrencyPair(base: pair.quote, quote: pair.base)];
    if (inverse != null) {
      return inverse;
    }
    throw StateError('No prices for ${pair.base.name}/${pair.quote.name}');
  }

  PriceQuote? latestPrice(CurrencyPair pair) {
    if (pair.base == pair.quote) {
      return PriceQuote(rate: Decimal.one);
    }
    try {
      final prices = allPrices(pair);
      if (prices.isEmpty) {
        return null;
      }
      final last = prices.last;
      return PriceQuote(date: last.date, rate: last.rate);
    } on StateError {
      return null;
    }
  }

  PriceQuote? priceAt(CurrencyPair pair, [BeanDate? date]) {
    if (date == null) {
      return latestPrice(pair);
    }
    if (pair.base == pair.quote) {
      return PriceQuote(rate: Decimal.one);
    }
    try {
      final prices = allPrices(pair);
      PricePoint? found;
      for (final point in prices) {
        if (compareBeanDate(point.date, date) <= 0) {
          found = point;
        } else {
          break;
        }
      }
      return found == null ? null : PriceQuote(date: found.date, rate: found.rate);
    } on StateError {
      return null;
    }
  }

  PriceMap project(Currency fromQuote, Currency toQuote, {Set<Currency>? baseCurrencies}) {
    if (fromQuote == toQuote) {
      return this;
    }
    final next = <CurrencyPair, List<PricePoint>>{
      for (final entry in rates.entries) entry.key: [...entry.value],
    };
    final conversionPair = CurrencyPair(base: fromQuote, quote: toQuote);

    for (final entry in Map<CurrencyPair, List<PricePoint>>.from(rates).entries) {
      if (entry.key.quote != fromQuote) {
        continue;
      }
      final base = entry.key.base;
      if (baseCurrencies != null && !baseCurrencies.contains(base)) {
        continue;
      }
      final target = CurrencyPair(base: base, quote: toQuote);
      final existingDates = {for (final point in next[target] ?? const <PricePoint>[]) point.date};
      final projected = <PricePoint>[];
      for (final point in entry.value) {
        final rate = priceAt(conversionPair, point.date);
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
      final merged = [...(next[target] ?? const <PricePoint>[]), ...projected]
        ..sort((a, b) => compareBeanDate(a.date, b.date));
      next[target] = merged;
      final inverted = CurrencyPair(base: toQuote, quote: base);
      next[inverted] = [
        ...(next[inverted] ?? const <PricePoint>[]),
        for (final point in projected)
          PricePoint(
            date: point.date,
            rate: point.rate == Decimal.zero
                ? Decimal.zero
                : (Decimal.one / point.rate).toDecimal(scaleOnInfinitePrecision: 28),
          ),
      ]..sort((a, b) => compareBeanDate(a.date, b.date));
    }

    return PriceMap(rates: next, forwardPairs: forwardPairs);
  }
}
