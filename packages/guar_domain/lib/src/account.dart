// Colon-separated account name with its balance-sheet or income-statement kind.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';

enum AccountType { assets, liabilities, equity, income, expenses }

@freezed
abstract class Account with _$Account {
  const Account._();

  const factory Account({required String name, required AccountType type}) = _Account;

  bool isSubaccountOf(Account other) => name.startsWith('${other.name}:');
}

@freezed
abstract class Currency with _$Currency {
  const factory Currency({required String name}) = _Currency;
}

@freezed
abstract class Tag with _$Tag {
  const factory Tag({required String name}) = _Tag;
}

@freezed
abstract class Link with _$Link {
  const factory Link({required String name}) = _Link;
}
