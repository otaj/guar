// Civil calendar date from Beancount directives (no time of day).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/validation.dart';

part 'date.freezed.dart';

int compareBeanDate(BeanDate left, BeanDate right) {
  final int byYear = left.year.compareTo(right.year);
  if (byYear != 0) return byYear;
  final int byMonth = left.month.compareTo(right.month);
  if (byMonth != 0) return byMonth;
  return left.day.compareTo(right.day);
}

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanDate with _$BeanDate {
  factory BeanDate({required int year, required int month, required int day}) {
    ensureBeanDate(year, month, day);
    return BeanDate._create(year: year, month: month, day: day);
  }
  const BeanDate._();

  const factory BeanDate._create({required int year, required int month, required int day}) = _BeanDate;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
