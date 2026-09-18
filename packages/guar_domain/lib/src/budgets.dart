// Fava-style budget proration: each civil day in [begin, end) gets budget/days-in-that-day's-period.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rational/rational.dart';

import 'account.dart';
import 'amount.dart';
import 'date.dart';
import 'date_delta.dart';
import 'directive.dart';
import 'location.dart';
import 'origin.dart';

part 'budgets.freezed.dart';

@freezed
abstract class BudgetCurrencyStatus with _$BudgetCurrencyStatus {
  const BudgetCurrencyStatus._();

  const factory BudgetCurrencyStatus({required Amount budget, required Amount actual}) = _BudgetCurrencyStatus;

  Currency get currency => budget.currency;

  Amount get remaining => Amount.sub(budget, actual);

  bool get within => actual.number <= budget.number;
}

@freezed
abstract class BudgetPeriod with _$BudgetPeriod {
  const BudgetPeriod._();

  const factory BudgetPeriod({
    @Default([]) List<BudgetCurrencyStatus> currencies,
    @Default([]) List<ProcessingWarning> warnings,
  }) = _BudgetPeriod;

  bool? get within => currencies.isEmpty ? null : currencies.every((row) => row.within);
}

class BudgetMap {
  BudgetMap._(this._budgets, this._postings);

  final Map<String, List<_Budget>> _budgets;
  final List<_Posted> _postings;

  factory BudgetMap.build(Iterable<Directive> directives) {
    final budgets = <String, List<_Budget>>{};
    final postings = <_Posted>[];
    var index = 0;
    for (final directive in directives) {
      switch (directive.body) {
        case BudgetBody(:final account, :final interval, :final amount):
          budgets
              .putIfAbsent(account.name, () => [])
              .add(_Budget(index: index, date: directive.date, interval: interval, amount: amount));
        case TransactionBody(:final value):
          for (final posting in value.postings) {
            postings.add(
              _Posted(
                date: directive.date,
                account: posting.account,
                units: posting.units,
                origin: posting.origin,
                directiveOrigin: directive.origin,
              ),
            );
          }
        default:
          break;
      }
      index += 1;
    }
    for (final list in budgets.values) {
      list.sort((left, right) {
        final byDate = compareBeanDate(left.date, right.date);
        if (byDate != 0) return byDate;
        return left.index.compareTo(right.index);
      });
    }
    postings.retainWhere((posted) {
      for (final name in budgets.keys) {
        if (_matches(posted.account.name, name, includeChildren: true)) return true;
      }
      return false;
    });
    return BudgetMap._(budgets, postings);
  }

  List<Amount> allowed(String account, BeanDate begin, BeanDate end, {bool includeChildren = false}) {
    final totals = <String, Decimal>{};
    final currencies = <String, Currency>{};
    for (final name in _budgets.keys) {
      if (!_matches(name, account, includeChildren: includeChildren)) continue;
      for (final amount in _allowedFor(name, begin, end)) {
        totals.update(amount.currency.name, (value) => value + amount.number, ifAbsent: () => amount.number);
        currencies[amount.currency.name] = amount.currency;
      }
    }
    return _amounts(totals, currencies);
  }

  List<Amount> actual(String account, BeanDate begin, BeanDate end, {bool includeChildren = false}) {
    final totals = <String, Decimal>{};
    final currencies = <String, Currency>{};
    for (final posting in _counted(account, begin, end, includeChildren: includeChildren)) {
      final currency = posting.units.currency;
      totals.update(currency.name, (value) => value + posting.units.number, ifAbsent: () => posting.units.number);
      currencies[currency.name] = currency;
    }
    return _amounts(totals, currencies);
  }

  BudgetPeriod period(String account, BeanDate begin, BeanDate end, {bool includeChildren = false}) {
    final budgeted = {
      for (final amount in allowed(account, begin, end, includeChildren: includeChildren)) amount.currency.name: amount,
    };
    final spent = {
      for (final amount in actual(account, begin, end, includeChildren: includeChildren)) amount.currency.name: amount,
    };
    final names = budgeted.keys.toList()..sort();
    final warnings = <ProcessingWarning>[];
    if (budgeted.isNotEmpty) {
      for (final posting in _counted(account, begin, end, includeChildren: includeChildren)) {
        if (budgeted.containsKey(posting.units.currency.name)) continue;
        final location = _warningLocation(posting);
        if (location == null) continue;
        warnings.add(
          ProcessingWarning(
            message:
                'Ignored ${posting.units} posting on ${posting.account.name}; no budget in ${posting.units.currency.name}',
            location: location,
          ),
        );
      }
    }
    return BudgetPeriod(
      currencies: [
        for (final name in names)
          BudgetCurrencyStatus(
            budget: budgeted[name]!,
            actual: spent[name] ?? Amount(number: Decimal.zero, currency: budgeted[name]!.currency),
          ),
      ],
      warnings: warnings,
    );
  }

  List<Amount> _allowedFor(String account, BeanDate begin, BeanDate end) {
    final list = _budgets[account];
    if (list == null || list.isEmpty) return const [];
    final totals = <String, Rational>{};
    final currencies = <String, Currency>{};
    for (final day in _daysInRange(begin, end)) {
      for (final budget in _active(list, day).values) {
        final days = _daysInContainingPeriod(budget.interval, day);
        final share = budget.amount.number / Decimal.fromInt(days);
        totals.update(budget.amount.currency.name, (value) => value + share, ifAbsent: () => share);
        currencies[budget.amount.currency.name] = budget.amount.currency;
      }
    }
    final names = totals.keys.toList()..sort();
    return [
      for (final name in names)
        Amount(number: totals[name]!.toDecimal(scaleOnInfinitePrecision: 28), currency: currencies[name]!),
    ];
  }

  Iterable<_Posted> _counted(String account, BeanDate begin, BeanDate end, {required bool includeChildren}) sync* {
    for (final posting in _postings) {
      if (compareBeanDate(posting.date, begin) < 0 || compareBeanDate(posting.date, end) >= 0) continue;
      if (!_counts(posting.account.name, account, includeChildren: includeChildren)) continue;
      yield posting;
    }
  }

  bool _counts(String postingAccount, String requested, {required bool includeChildren}) {
    for (final budgeted in _budgets.keys) {
      if (!_matches(budgeted, requested, includeChildren: includeChildren)) continue;
      if (_matches(postingAccount, budgeted, includeChildren: includeChildren)) return true;
    }
    return false;
  }

  Map<String, _Budget> _active(List<_Budget> budgets, BeanDate day) {
    final last = <String, _Budget>{};
    for (final budget in budgets) {
      if (compareBeanDate(budget.date, day) <= 0) {
        last[budget.amount.currency.name] = budget;
      } else {
        break;
      }
    }
    return last;
  }
}

class _Budget {
  _Budget({required this.index, required this.date, required this.interval, required this.amount});

  final int index;
  final BeanDate date;
  final BudgetInterval interval;
  final Amount amount;
}

class _Posted {
  _Posted({
    required this.date,
    required this.account,
    required this.units,
    required this.origin,
    required this.directiveOrigin,
  });

  final BeanDate date;
  final Account account;
  final Amount units;
  final Origin origin;
  final Origin directiveOrigin;
}

BeanLocation? _warningLocation(_Posted posted) {
  return switch (posted.origin) {
    SourceOrigin(:final location) => location,
    GeneratedOrigin() => switch (posted.directiveOrigin) {
      SourceOrigin(:final location) => location,
      GeneratedOrigin() => null,
    },
  };
}

bool _matches(String candidate, String requested, {required bool includeChildren}) {
  return includeChildren ? isAccountOrSubaccount(candidate, requested) : candidate == requested;
}

Iterable<BeanDate> _daysInRange(BeanDate begin, BeanDate end) sync* {
  var current = begin;
  while (compareBeanDate(current, end) < 0) {
    yield current;
    current = addDays(current, 1);
  }
}

int _daysInContainingPeriod(BudgetInterval interval, BeanDate day) {
  final start = _periodStart(interval, day);
  return _utc(_periodNext(interval, start)).difference(_utc(start)).inDays;
}

BeanDate _periodStart(BudgetInterval interval, BeanDate day) {
  return switch (interval) {
    BudgetInterval.daily => day,
    BudgetInterval.weekly => addDays(day, 1 - _utc(day).weekday),
    BudgetInterval.monthly => BeanDate(year: day.year, month: day.month, day: 1),
    BudgetInterval.quarterly => BeanDate(year: day.year, month: (day.month - 1) ~/ 3 * 3 + 1, day: 1),
    BudgetInterval.yearly => BeanDate(year: day.year, month: 1, day: 1),
  };
}

BeanDate _periodNext(BudgetInterval interval, BeanDate start) {
  return switch (interval) {
    BudgetInterval.daily => addDays(start, 1),
    BudgetInterval.weekly => addDays(start, 7),
    BudgetInterval.monthly => addDelta(start, const DateDelta(months: 1)),
    BudgetInterval.quarterly => addDelta(start, const DateDelta(months: 3)),
    BudgetInterval.yearly => addDelta(start, const DateDelta(years: 1)),
  };
}

DateTime _utc(BeanDate date) => DateTime.utc(date.year, date.month, date.day);

List<Amount> _amounts(Map<String, Decimal> totals, Map<String, Currency> currencies) {
  final names = totals.keys.toList()..sort();
  return [for (final name in names) Amount(number: totals[name]!, currency: currencies[name]!)];
}
