// Units, cost, weight, and market value over booked positions.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

Amount unitsOf(Position position) => position.units;

Amount costOf(Position position) {
  final Cost? cost = position.cost;
  if (cost == null) return position.units;
  return Amount(number: position.units.number * cost.number, currency: cost.currency);
}

Amount weightOf(Posting posting) {
  final Cost? cost = posting.cost;
  if (cost != null) {
    return Amount(number: posting.units.number * cost.number, currency: cost.currency);
  }
  final Amount? price = posting.price;
  if (price != null) {
    return Amount(number: posting.units.number * price.number, currency: price.currency);
  }
  return posting.units;
}

Amount? convertAmount(Amount amount, Currency target, PriceMap prices, [BeanDate? date]) {
  if (amount.currency == target) return amount;
  final PriceQuote? quote = prices.priceAt(CurrencyPair(base: amount.currency, quote: target), date);
  if (quote == null) return null;
  return Amount(number: amount.number * quote.rate, currency: target);
}

Amount? convertPosition(Position position, Currency target, PriceMap prices, [BeanDate? date]) =>
    convertAmount(costOf(position), target, prices, date) ?? convertAmount(position.units, target, prices, date);

Amount? marketValue(Position position, PriceMap prices, [BeanDate? date]) {
  final Cost? cost = position.cost;
  if (cost == null) return position.units;
  return convertAmount(position.units, cost.currency, prices, date) ?? costOf(position);
}

Inventory reduceUnits(Inventory inventory) {
  Inventory result = const Inventory();
  for (final Position position in inventory.positions) {
    result = result.addAmount(position.units).inventory;
  }
  return result;
}

Inventory reduceCost(Inventory inventory) {
  Inventory result = const Inventory();
  for (final Position position in inventory.positions) {
    result = result.addAmount(costOf(position)).inventory;
  }
  return result;
}

Inventory reduceValue(Inventory inventory, PriceMap prices, [BeanDate? date]) {
  Inventory result = const Inventory();
  for (final Position position in inventory.positions) {
    final Amount? value = marketValue(position, prices, date);
    if (value != null) {
      result = result.addAmount(value).inventory;
    }
  }
  return result;
}

Inventory reduceConvert(Inventory inventory, Currency target, PriceMap prices, [BeanDate? date]) {
  Inventory result = const Inventory();
  for (final Position position in inventory.positions) {
    final Amount? converted = convertPosition(position, target, prices, date);
    if (converted != null) {
      result = result.addAmount(converted).inventory;
    }
  }
  return result;
}

Inventory inventoryFromAmount(Amount amount) => const Inventory().addAmount(amount).inventory;

Inventory inventoryFromPosition(Position position) => const Inventory().addPosition(position).inventory;

Decimal? getPrice(PriceMap prices, String base, String quote, [BeanDate? date]) {
  final CurrencyPair pair = CurrencyPair(
    base: Currency(name: base.toUpperCase()),
    quote: Currency(name: quote.toUpperCase()),
  );
  return prices.priceAt(pair, date)?.rate;
}
