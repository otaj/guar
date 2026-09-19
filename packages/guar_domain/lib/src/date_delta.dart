// Civil calendar duration used by date interval functions.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'date_delta.freezed.dart';

@freezed
abstract class DateDelta with _$DateDelta {
  const factory DateDelta({@Default(0) int years, @Default(0) int months, @Default(0) int days}) = _DateDelta;
  const DateDelta._();

  bool get isZero => years == 0 && months == 0 && days == 0;
}
