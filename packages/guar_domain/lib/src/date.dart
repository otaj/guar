// Civil calendar date from Beancount directives (no time of day).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation.dart';

part 'date.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanDate with _$BeanDate {
  const BeanDate._();

  factory BeanDate({required int year, required int month, required int day}) {
    ensureBeanDate(year, month, day);
    return BeanDate._create(year: year, month: month, day: day);
  }

  const factory BeanDate._create({required int year, required int month, required int day}) = _BeanDate;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
