// One posting after booking and interpolation.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'cost.dart';
import 'flag.dart';
import 'meta.dart';
import 'origin.dart';

part 'posting.freezed.dart';

@freezed
abstract class Posting with _$Posting {
  const factory Posting({
    required Origin origin,
    @Default(Meta()) Meta meta,
    Flag? flag,
    required Account account,
    required Amount units,
    Cost? cost,
    Amount? price,
  }) = _Posting;
}
