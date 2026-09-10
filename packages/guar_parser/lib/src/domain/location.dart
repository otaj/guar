// Source span of a parsed construct.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';

@freezed
abstract class BeanLocation with _$BeanLocation {
  const BeanLocation._();

  const factory BeanLocation({@Default('') String filename, required int linenoBegin, required int linenoEnd}) =
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
    return copyWith(linenoBegin: linenoBegin + delta, linenoEnd: linenoEnd + delta);
  }
}
