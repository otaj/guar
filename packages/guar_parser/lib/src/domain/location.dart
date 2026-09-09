// Source span of a parsed construct.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';

@freezed
abstract class BeanLocation with _$BeanLocation {
  const factory BeanLocation({@Default('') String filename, required int linenoBegin, required int linenoEnd}) =
      _BeanLocation;
}
