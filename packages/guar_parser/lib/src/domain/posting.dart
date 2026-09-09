// One posting of a transaction as produced by the parser.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'cost.dart';
import 'flag.dart';
import 'location.dart';
import 'meta.dart';

part 'posting.freezed.dart';

@freezed
abstract class ParsedPosting with _$ParsedPosting {
  const factory ParsedPosting({
    required BeanLocation location,
    @Default(Meta()) Meta meta,
    Flag? flag,
    required Account account,
    IncompleteAmount? units,
    ParsedCost? cost,
    IncompleteAmount? price,
  }) = _ParsedPosting;
}
