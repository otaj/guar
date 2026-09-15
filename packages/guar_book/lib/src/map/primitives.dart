// Map parsed amounts, costs, prices, meta, and flags into booked domain types.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

import '../options_defaults.dart';

d.Amount mapAmount(p.Amount amount) => d.Amount(
  number: amount.number.resolved,
  currency: d.Currency(name: amount.currency.name),
);

d.Amount? mapCompleteUnits(p.IncompleteAmount? units) {
  if (units == null || units.number == null || units.currency == null) {
    return null;
  }
  return d.Amount(
    number: units.number!.resolved,
    currency: d.Currency(name: units.currency!.name),
  );
}

d.Cost? mapResolvedCost(p.ParsedCost? cost, d.BeanDate txnDate, Decimal unitsAbs) {
  if (cost == null) {
    return null;
  }
  final per = cost.numberPer?.resolved;
  final total = cost.numberTotal?.resolved;
  if (cost.currency == null) {
    return null;
  }
  Decimal? unitCost;
  if (total != null) {
    var costTotal = total;
    if (per != null) {
      costTotal += per * unitsAbs;
    }
    if (unitsAbs == Decimal.zero) {
      return null;
    }
    unitCost = (costTotal / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28);
  } else if (per != null) {
    unitCost = per;
  }
  if (unitCost == null) {
    return null;
  }
  return d.Cost(
    number: unitCost,
    currency: d.Currency(name: cost.currency!.name),
    date: cost.date == null ? txnDate : d.BeanDate(year: cost.date!.year, month: cost.date!.month, day: cost.date!.day),
    label: cost.label,
  );
}

d.Amount? mapPrice(p.ParsedPrice? price, Decimal? unitsAbs) {
  if (price == null || price.number == null || price.currency == null) {
    return null;
  }
  var number = price.number!.resolved;
  if (price.isTotal) {
    if (unitsAbs == null || unitsAbs == Decimal.zero) {
      return null;
    }
    number = (number / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28);
  }
  return d.Amount(
    number: number,
    currency: d.Currency(name: price.currency!.name),
  );
}

d.Flag mapFlag(p.Flag flag) => switch (flag) {
  p.SpecialFlagValue(:final value) => d.Flag.special(_special(value)),
  p.LetterFlag(:final value) => d.Flag.letter(value),
};

d.SpecialFlag _special(p.SpecialFlag value) => switch (value) {
  p.SpecialFlag.asterisk => d.SpecialFlag.asterisk,
  p.SpecialFlag.exclamation => d.SpecialFlag.exclamation,
  p.SpecialFlag.hash => d.SpecialFlag.hash,
  p.SpecialFlag.ampersand => d.SpecialFlag.ampersand,
  p.SpecialFlag.question => d.SpecialFlag.question,
  p.SpecialFlag.percent => d.SpecialFlag.percent,
};

d.Meta mapMeta(p.Meta meta) => d.Meta(
  entries: [
    for (final entry in meta.entries)
      d.MetaEntry(key: entry.key, value: entry.value == null ? null : _metaValue(entry.value!)),
  ],
);

d.MetaValue _metaValue(p.MetaValue value) => switch (value) {
  p.MetaText(:final value) => d.MetaValue.text(value),
  p.MetaAccount(:final value) => d.MetaValue.account(d.Account(name: value.name, type: d.AccountType.assets)),
  p.MetaCurrency(:final value) => d.MetaValue.currency(d.Currency(name: value.name)),
  p.MetaTag(:final value) => d.MetaValue.tag(d.Tag(name: value.name)),
  p.MetaDate(:final value) => d.MetaValue.date(d.BeanDate(year: value.year, month: value.month, day: value.day)),
  p.MetaBoolean(:final value) => d.MetaValue.boolean(value),
  p.MetaNumber(:final value) => d.MetaValue.number(value.resolved),
  p.MetaAmount(:final value) => d.MetaValue.amount(mapAmount(value)),
};

d.BeanDate mapDate(p.BeanDate date) => d.BeanDate(year: date.year, month: date.month, day: date.day);

d.Origin sourceOrigin(p.BeanLocation location) => d.Origin.source(mapLocation(location));
