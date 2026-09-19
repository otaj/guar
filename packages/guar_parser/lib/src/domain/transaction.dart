// Transaction body after parsing, before booking.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/flag.dart';
import 'package:guar_parser/src/domain/posting.dart';

part 'transaction.freezed.dart';

@freezed
abstract class ParsedTransaction with _$ParsedTransaction {
  const factory ParsedTransaction({
    required Flag flag,
    String? payee,
    @Default('') String narration,
    @Default(<dynamic>[]) List<Tag> tags,
    @Default(<dynamic>[]) List<Link> links,
    @Default(<dynamic>[]) List<ParsedPosting> postings,
  }) = _ParsedTransaction;
}
