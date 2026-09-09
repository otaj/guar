// Cost braces from a posting before booking.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'date.dart';
import 'number.dart';

part 'cost.freezed.dart';

@freezed
abstract class ParsedCost with _$ParsedCost {
  const factory ParsedCost({
    BeanNumber? numberPer,
    BeanNumber? numberTotal,
    Currency? currency,
    BeanDate? date,
    String? label,
    @Default(false) bool merge,
  }) = _ParsedCost;
}
