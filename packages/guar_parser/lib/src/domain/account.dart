// Colon-separated Beancount account name.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';

@freezed
abstract class Account with _$Account {
  const factory Account({required String name}) = _Account;
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
