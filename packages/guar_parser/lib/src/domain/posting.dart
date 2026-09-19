// One posting of a transaction as produced by the parser.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/amount.dart';
import 'package:guar_parser/src/domain/cost.dart';
import 'package:guar_parser/src/domain/flag.dart';
import 'package:guar_parser/src/domain/location.dart';
import 'package:guar_parser/src/domain/meta.dart';

part 'posting.freezed.dart';

@freezed
abstract class ParsedPosting with _$ParsedPosting {
  const factory ParsedPosting({
    required BeanLocation location,
    required Account account,
    @Default(Meta()) Meta meta,
    Flag? flag,
    IncompleteAmount? units,
    ParsedCost? cost,
    ParsedPrice? price,
  }) = _ParsedPosting;
}
