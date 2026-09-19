// Cost braces from a posting before booking.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/date.dart';
import 'package:guar_parser/src/domain/number.dart';

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
