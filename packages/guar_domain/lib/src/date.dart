// Civil calendar date from Beancount directives (no time of day).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'date_delta.dart';
import 'validation.dart';

part 'date.freezed.dart';

int compareBeanDate(BeanDate left, BeanDate right) {
  final byYear = left.year.compareTo(right.year);
  if (byYear != 0) return byYear;
  final byMonth = left.month.compareTo(right.month);
  if (byMonth != 0) return byMonth;
  return left.day.compareTo(right.day);
}

BeanDate addDays(BeanDate date, int days) {
  final native = DateTime.utc(date.year, date.month, date.day).add(Duration(days: days));
  return BeanDate(year: native.year, month: native.month, day: native.day);
}

BeanDate addDelta(BeanDate date, DateDelta delta) {
  var year = date.year + delta.years;
  var month = date.month + delta.months;
  while (month > 12) {
    year += 1;
    month -= 12;
  }
  while (month < 1) {
    year -= 1;
    month += 12;
  }
  final lastDay = daysInMonth(year, month);
  final day = date.day < lastDay ? date.day : lastDay;
  return addDays(BeanDate(year: year, month: month, day: day), delta.days);
}

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
