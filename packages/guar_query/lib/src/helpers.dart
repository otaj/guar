// Shared calendar, account-prefix, and comparison helpers for BQL.

import 'package:guar_domain/guar_domain.dart';

int compareBeanDate(BeanDate left, BeanDate right) {
  final byYear = left.year.compareTo(right.year);
  if (byYear != 0) return byYear;
  final byMonth = left.month.compareTo(right.month);
  if (byMonth != 0) return byMonth;
  return left.day.compareTo(right.day);
}

BeanDate addDays(BeanDate date, int days) {
  final native = DateTime.utc(date.year, date.month, date.day).add(Duration(days: days));
  return BeanDate(year: native.year, month: native.month, day: native.day);
}

BeanDate addDelta(BeanDate date, DateDelta delta) {
  var year = date.year + delta.years;
  var month = date.month + delta.months;
  while (month > 12) {
    year += 1;
    month -= 12;
  }
  while (month < 1) {
    year -= 1;
    month += 12;
  }
  final lastDay = daysInMonth(year, month);
  final day = date.day < lastDay ? date.day : lastDay;
  return addDays(BeanDate(year: year, month: month, day: day), delta.days);
}

DateDelta? parseInterval(String text) {
  final match = RegExp(r'^([+-]?\d+)\s+(day|week|month|year|decade|century|millennium)s?$').firstMatch(text.trim());
  if (match == null) return null;
  final number = int.parse(match.group(1)!);
  return switch (match.group(2)!) {
    'day' => DateDelta(days: number),
    'week' => DateDelta(days: number * 7),
    'month' => DateDelta(months: number),
    'year' => DateDelta(years: number),
    'decade' => DateDelta(years: number * 10),
    'century' => DateDelta(years: number * 100),
    'millennium' => DateDelta(years: number * 1000),
    _ => null,
  };
}

AccountType accountTypeFor(String name, AccountPrefixes prefixes) {
  if (_hasPrefix(name, prefixes.assets)) return AccountType.assets;
  if (_hasPrefix(name, prefixes.liabilities)) return AccountType.liabilities;
  if (_hasPrefix(name, prefixes.equity)) return AccountType.equity;
  if (_hasPrefix(name, prefixes.income)) return AccountType.income;
  if (_hasPrefix(name, prefixes.expenses)) return AccountType.expenses;
  return AccountType.assets;
}

bool _hasPrefix(String name, String? prefix) {
  if (prefix == null || prefix.isEmpty) return false;
  return name == prefix || name.startsWith('$prefix:');
}

Account accountFor(String name, LedgerOptions options) =>
    Account(name: name, type: accountTypeFor(name, options.accountPrefixes));

int accountSign(Account account) => switch (account.type) {
  AccountType.assets || AccountType.expenses => 1,
  AccountType.liabilities || AccountType.equity || AccountType.income => -1,
};

String accountSortKey(Account account) {
  final index = switch (account.type) {
    AccountType.assets => 1,
    AccountType.liabilities => 2,
    AccountType.equity => 3,
    AccountType.income => 4,
    AccountType.expenses => 5,
  };
  return '$index-${account.name}';
}

String parentAccount(String name) {
  final index = name.lastIndexOf(':');
  return index < 0 ? '' : name.substring(0, index);
}

String leafAccount(String name) {
  final index = name.lastIndexOf(':');
  return index < 0 ? name : name.substring(index + 1);
}

String rootAccount(String name, int n) {
  final parts = name.split(':');
  if (n <= 0) return '';
  return parts.take(n).join(':');
}

bool isIncomeStatement(Account account) => account.type == AccountType.income || account.type == AccountType.expenses;
