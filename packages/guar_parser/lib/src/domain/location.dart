// Source span of a parsed construct.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/validation.dart';

part 'location.freezed.dart';

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class BeanLocation with _$BeanLocation {
  factory BeanLocation({required int linenoBegin, required int linenoEnd, String filename = ''}) {
    ensureLocationLines(linenoBegin, linenoEnd);
    return BeanLocation._create(filename: filename, linenoBegin: linenoBegin, linenoEnd: linenoEnd);
  }
  const BeanLocation._();

  const factory BeanLocation._create({required int linenoBegin, required int linenoEnd, @Default('') String filename}) =
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
