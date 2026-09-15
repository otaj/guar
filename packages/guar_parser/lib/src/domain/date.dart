// Civil calendar date from Beancount directives (no time of day).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'date.freezed.dart';

@freezed
abstract class BeanDate with _$BeanDate {
  const BeanDate._();

  const factory BeanDate({required int year, required int month, required int day}) = _BeanDate;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
