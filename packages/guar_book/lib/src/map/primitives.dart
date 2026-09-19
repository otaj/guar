// Map parsed amounts, costs, prices, meta, and flags into booked domain types.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/options_defaults.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

d.Amount mapAmount(p.Amount amount) => d.Amount(
  number: amount.number.resolved,
  currency: d.Currency(name: amount.currency.name),
  scale: amount.number.places,
);

d.Amount? mapCompleteUnits(p.IncompleteAmount? units) {
  if (units == null || units.number == null || units.currency == null) {
    return null;
  }
  return d.Amount(
    number: units.number!.resolved,
    currency: d.Currency(name: units.currency!.name),
    scale: units.number!.places,
  );
}

d.Cost? mapResolvedCost(p.ParsedCost? cost, d.BeanDate txnDate, Decimal unitsAbs) {
  if (cost == null) {
    return null;
  }
  final Decimal? per = cost.numberPer?.resolved;
  final Decimal? total = cost.numberTotal?.resolved;
  if (cost.currency == null) {
    return null;
  }
  Decimal? unitCost;
  if (total != null) {
    Decimal costTotal = total;
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
  Decimal number = price.number!.resolved;
  if (price.isTotal) {
    if (unitsAbs == null || unitsAbs == Decimal.zero) {
      return null;
    }
    number = (number / unitsAbs).toDecimal(scaleOnInfinitePrecision: 28);
  }
  return d.Amount(
    number: number,
    currency: d.Currency(name: price.currency!.name),
    scale: price.number!.places,
  );
}

d.Flag mapFlag(p.Flag flag) => switch (flag) {
  p.SpecialFlagValue(:final p.SpecialFlag value) => d.Flag.special(_special(value)),
  p.LetterFlag(:final String value) => d.Flag.letter(value),
};

d.SpecialFlag _special(p.SpecialFlag value) => switch (value) {
  p.SpecialFlag.asterisk => d.SpecialFlag.asterisk,
  p.SpecialFlag.exclamation => d.SpecialFlag.exclamation,
  p.SpecialFlag.hash => d.SpecialFlag.hash,
  p.SpecialFlag.ampersand => d.SpecialFlag.ampersand,
  p.SpecialFlag.question => d.SpecialFlag.question,
  p.SpecialFlag.percent => d.SpecialFlag.percent,
};

d.Meta mapMeta(p.Meta meta, d.AccountPrefixes prefixes) => d.Meta(
  entries: <d.MetaEntry>[
    for (final p.MetaEntry entry in meta.entries)
      d.MetaEntry(key: entry.key, value: entry.value == null ? null : _metaValue(entry.value!, prefixes)),
  ],
);

d.MetaValue _metaValue(p.MetaValue value, d.AccountPrefixes prefixes) => switch (value) {
  p.MetaText(:final String value) => d.MetaValue.text(value),
  p.MetaAccount(:final p.Account value) => d.MetaValue.account(prefixes.account(value.name)),
  p.MetaCurrency(:final p.Currency value) => d.MetaValue.currency(d.Currency(name: value.name)),
  p.MetaTag(:final p.Tag value) => d.MetaValue.tag(d.Tag(name: value.name)),
  p.MetaDate(:final p.BeanDate value) => d.MetaValue.date(
    d.BeanDate(year: value.year, month: value.month, day: value.day),
  ),
  p.MetaBoolean(:final bool value) => d.MetaValue.boolean(value),
  p.MetaNumber(:final p.BeanNumber value) => d.MetaValue.number(value.resolved),
  p.MetaAmount(:final p.Amount value) => d.MetaValue.amount(mapAmount(value)),
};

d.BeanDate mapDate(p.BeanDate date) => d.BeanDate(year: date.year, month: date.month, day: date.day);

d.Origin sourceOrigin(p.BeanLocation location) => d.Origin.source(mapLocation(location));
