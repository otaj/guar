// Colon-separated Beancount account name.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/validation.dart';

part 'account.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Account with _$Account {
  factory Account({required String name}) {
    ensureAccountName(name);
    return Account._create(name: name);
  }

  const factory Account._create({required String name}) = _Account;
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
