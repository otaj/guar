// Complete, incomplete, and price amounts attached to postings and directives.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'number.dart';

part 'amount.freezed.dart';

@freezed
abstract class Amount with _$Amount {
  const factory Amount({required BeanNumber number, required Currency currency}) = _Amount;
}

@freezed
abstract class IncompleteAmount with _$IncompleteAmount {
  const factory IncompleteAmount({BeanNumber? number, Currency? currency}) = _IncompleteAmount;
}

@freezed
abstract class ParsedPrice with _$ParsedPrice {
  const factory ParsedPrice({BeanNumber? number, Currency? currency, @Default(false) bool isTotal}) = _ParsedPrice;
}
