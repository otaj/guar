// Source span of a booked construct.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/validation.dart';

part 'location.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanLocation with _$BeanLocation {
  factory BeanLocation({required int linenoBegin, required int linenoEnd, String filename = ''}) {
    ensureLocationLines(linenoBegin, linenoEnd);
    return BeanLocation._create(filename: filename, linenoBegin: linenoBegin, linenoEnd: linenoEnd);
  }

  const factory BeanLocation._create({required int linenoBegin, required int linenoEnd, @Default('') String filename}) =
      _BeanLocation;
}
