// Civil calendar date from Beancount directives (no time of day).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'date.freezed.dart';

@freezed
abstract class BeanDate with _$BeanDate {
  const factory BeanDate({required int year, required int month, required int day}) = _BeanDate;
}
