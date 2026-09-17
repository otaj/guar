// Account name helpers and BQL interval parsing.

import 'package:guar_domain/guar_domain.dart';

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

Account accountFor(String name, LedgerOptions options) => options.accountPrefixes.account(name);

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
