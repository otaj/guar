// One posting after booking and interpolation.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/cost.dart';
import 'package:guar_domain/src/flag.dart';
import 'package:guar_domain/src/meta.dart';
import 'package:guar_domain/src/origin.dart';

part 'posting.freezed.dart';

@freezed
abstract class Posting with _$Posting {
  const factory Posting({
    required Origin origin,
    required Account account,
    required Amount units,
    @Default(Meta()) Meta meta,
    Flag? flag,
    Cost? cost,
    Amount? price,
  }) = _Posting;
}
