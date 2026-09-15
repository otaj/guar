// Source span of a parsed construct.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation.dart';

part 'location.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanLocation with _$BeanLocation {
  const BeanLocation._();

  factory BeanLocation({String filename = '', required int linenoBegin, required int linenoEnd}) {
    ensureLocationLines(linenoBegin, linenoEnd);
    return BeanLocation._create(filename: filename, linenoBegin: linenoBegin, linenoEnd: linenoEnd);
  }

  const factory BeanLocation._create({@Default('') String filename, required int linenoBegin, required int linenoEnd}) =
      _BeanLocation;

  bool overlapsFileRange(String filename, int startLine, int endLine) {
    if (endLine < startLine || this.filename != filename) {
      return false;
    }
    return linenoBegin <= endLine && linenoEnd >= startLine;
  }

  BeanLocation shifted(int delta) {
    if (delta == 0) {
      return this;
    }
    return BeanLocation(filename: filename, linenoBegin: linenoBegin + delta, linenoEnd: linenoEnd + delta);
  }
}
