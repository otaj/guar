// Source span of a booked construct.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation.dart';

part 'location.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanLocation with _$BeanLocation {
  factory BeanLocation({String filename = '', required int linenoBegin, required int linenoEnd}) {
    ensureLocationLines(linenoBegin, linenoEnd);
    return BeanLocation._create(filename: filename, linenoBegin: linenoBegin, linenoEnd: linenoEnd);
  }

  const factory BeanLocation._create({@Default('') String filename, required int linenoBegin, required int linenoEnd}) =
      _BeanLocation;
}
