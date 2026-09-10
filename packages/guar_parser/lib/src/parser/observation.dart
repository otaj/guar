// Collects observed commodities and inferred display precision from parsed directives.

import 'package:decimal/decimal.dart';

import '../domain/domain.dart';

({List<Currency> commodities, DisplayContext displayContext}) observeDirectives(Iterable<ParsedDirective> directives) {
  final names = <String>{};
  final digits = <String, List<int>>{};

  void seeCurrency(Currency? currency) {
    if (currency == null) {
      return;
    }
    names.add(currency.name);
  }

  void seeAmount(BeanNumber? number, Currency? currency) {
    seeCurrency(currency);
    if (number == null || currency == null) {
      return;
    }
    digits.putIfAbsent(currency.name, () => []).add(_fractionalDigits(number));
  }

  void seeMeta(Meta meta) {
    for (final entry in meta.entries) {
      switch (entry.value) {
        case MetaCurrency(:final value):
          seeCurrency(value);
        case MetaAmount(:final value):
          seeAmount(value.number, value.currency);
        case _:
          break;
      }
    }
  }

  for (final directive in directives) {
    seeMeta(directive.meta);
    switch (directive.body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          seeMeta(posting.meta);
          seeAmount(posting.units?.number, posting.units?.currency);
          final cost = posting.cost;
          if (cost != null) {
            seeCurrency(cost.currency);
            seeAmount(cost.numberPer, cost.currency);
            seeAmount(cost.numberTotal, cost.currency);
          }
          final price = posting.price;
          if (price != null) {
            seeAmount(price.number, price.currency);
          }
        }
      case PriceBody(:final currency, :final amount):
        seeCurrency(currency);
        seeAmount(amount.number, amount.currency);
      case BalanceBody(:final amount):
        seeAmount(amount.number, amount.currency);
      case OpenBody(:final currencies):
        for (final currency in currencies) {
          seeCurrency(currency);
        }
      case CommodityBody(:final currency):
        seeCurrency(currency);
      case CustomBody(:final values):
        for (final value in values) {
          if (value case CustomAmount(:final value)) {
            seeAmount(value.number, value.currency);
          }
        }
      case _:
        break;
    }
  }

  final commodities = [for (final name in (names.toList()..sort())) Currency(name: name)];
  final precisions = [
    for (final name in (digits.keys.toList()..sort()))
      DisplayPrecision(
        key: DisplayPrecisionKey.currency(Currency(name: name)),
        value: _quantum(_mode(digits[name]!)),
      ),
  ];
  return (commodities: List.unmodifiable(commodities), displayContext: DisplayContext(precisions: precisions));
}

int _fractionalDigits(BeanNumber number) {
  final compact = number.verbatim.replaceAll(',', '').replaceAll(' ', '');
  if (RegExp(r'^[+-]?\d+(\.\d+)?$').hasMatch(compact)) {
    final dot = compact.indexOf('.');
    return dot < 0 ? 0 : compact.length - dot - 1;
  }
  final resolved = number.resolved.toString();
  final dot = resolved.indexOf('.');
  return dot < 0 ? 0 : resolved.length - dot - 1;
}

int _mode(List<int> samples) {
  final hist = <int, int>{};
  for (final value in samples) {
    hist[value] = (hist[value] ?? 0) + 1;
  }
  var maxValue = 0;
  var maxCount = 0;
  final keys = hist.keys.toList()..sort();
  for (final value in keys) {
    final count = hist[value]!;
    if (count >= maxCount) {
      maxCount = count;
      maxValue = value;
    }
  }
  return maxValue;
}

BeanNumber _quantum(int fractionalDigits) {
  if (fractionalDigits <= 0) {
    return BeanNumber(verbatim: '1', resolved: Decimal.one);
  }
  final verbatim = '0.${'0' * (fractionalDigits - 1)}1';
  return BeanNumber(verbatim: verbatim, resolved: Decimal.parse(verbatim));
}
