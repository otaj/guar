// Collects commodities and display precision from transactions, prices, and balances.

import 'package:decimal/decimal.dart';

import 'package:guar_parser/src/domain/domain.dart';

({List<Currency> commodities, DisplayContext displayContext}) observeDirectives(Iterable<ParsedDirective> directives) {
  final Set<String> names = <String>{};
  final Map<String, List<int>> digits = <String, List<int>>{};

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
    digits.putIfAbsent(currency.name, () => <int>[]).add(_fractionalDigits(number));
  }

  for (final ParsedDirective directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final ParsedTransaction value):
        for (final ParsedPosting posting in value.postings) {
          seeAmount(posting.units?.number, posting.units?.currency);
          final ParsedCost? cost = posting.cost;
          if (cost != null) {
            seeCurrency(cost.currency);
            seeAmount(cost.numberPer, cost.currency);
            seeAmount(cost.numberTotal, cost.currency);
          }
          final ParsedPrice? price = posting.price;
          if (price != null) {
            seeAmount(price.number, price.currency);
          }
        }
      case PriceBody(:final Currency currency, :final Amount amount):
        seeCurrency(currency);
        seeAmount(amount.number, amount.currency);
      case BalanceBody(:final Amount amount):
        seeAmount(amount.number, amount.currency);
      default:
        break;
    }
  }

  final List<Currency> commodities = <Currency>[
    for (final String name in (names.toList()..sort())) Currency(name: name),
  ];
  final List<DisplayPrecision> precisions = <DisplayPrecision>[
    for (final String name in (digits.keys.toList()..sort()))
      DisplayPrecision(
        key: DisplayPrecisionKey.currency(Currency(name: name)),
        value: _quantum(_mode(digits[name]!)),
      ),
  ];
  return (
    commodities: List<Currency>.unmodifiable(commodities),
    displayContext: DisplayContext(precisions: precisions),
  );
}

int _fractionalDigits(BeanNumber number) {
  final String compact = number.verbatim.replaceAll(',', '').replaceAll(' ', '');
  if (RegExp(r'^[+-]?\d+(\.\d+)?$').hasMatch(compact)) {
    final int dot = compact.indexOf('.');
    return dot < 0 ? 0 : compact.length - dot - 1;
  }
  final String resolved = number.resolved.toString();
  final int dot = resolved.indexOf('.');
  return dot < 0 ? 0 : resolved.length - dot - 1;
}

int _mode(List<int> samples) {
  final Map<int, int> hist = <int, int>{};
  for (final int value in samples) {
    hist[value] = (hist[value] ?? 0) + 1;
  }
  int maxValue = 0;
  int maxCount = 0;
  final List<int> keys = hist.keys.toList()..sort();
  for (final int value in keys) {
    final int count = hist[value]!;
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
  final String verbatim = '0.${'0' * (fractionalDigits - 1)}1';
  return BeanNumber(verbatim: verbatim, resolved: Decimal.parse(verbatim));
}
