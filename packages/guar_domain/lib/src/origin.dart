// Whether a booked construct came from source or was generated.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/location.dart';

part 'origin.freezed.dart';

@freezed
sealed class Origin with _$Origin {
  const factory Origin.source(BeanLocation location) = SourceOrigin;
  const factory Origin.generated() = GeneratedOrigin;
}
