// Colon-separated account name with its balance-sheet or income-statement kind.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation.dart';

part 'account.freezed.dart';

enum AccountType { assets, liabilities, equity, income, expenses }

bool isSubaccountName(String name, String parent) => parent.isNotEmpty && name.startsWith('$parent:');

bool isAccountOrSubaccount(String name, String ancestor) =>
    ancestor.isNotEmpty && (name == ancestor || isSubaccountName(name, ancestor));

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Account with _$Account {
  const Account._();

  factory Account({required String name, required AccountType type}) {
    ensureAccountName(name);
    return Account._create(name: name, type: type);
  }

  factory Account.budget({required String name, required AccountType type}) {
    ensureBudgetAccountName(name);
    return Account._create(name: name, type: type);
  }

  const factory Account._create({required String name, required AccountType type}) = _Account;

  bool isSubaccountOf(Account other) => isSubaccountName(name, other.name);
}

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Currency with _$Currency {
  factory Currency({required String name}) {
    ensureCurrencyName(name);
    return Currency._create(name: name);
  }

  const factory Currency._create({required String name}) = _Currency;
}

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Tag with _$Tag {
  factory Tag({required String name}) {
    ensureTagOrLinkName(name, 'Tag.name');
    return Tag._create(name: name);
  }

  const factory Tag._create({required String name}) = _Tag;
}

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Link with _$Link {
  factory Link({required String name}) {
    ensureTagOrLinkName(name, 'Link.name');
    return Link._create(name: name);
  }

  const factory Link._create({required String name}) = _Link;
}
