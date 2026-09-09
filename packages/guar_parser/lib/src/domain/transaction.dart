// Transaction body after parsing, before booking.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'flag.dart';
import 'posting.dart';

part 'transaction.freezed.dart';

@freezed
abstract class ParsedTransaction with _$ParsedTransaction {
  const factory ParsedTransaction({
    required Flag flag,
    String? payee,
    @Default('') String narration,
    @Default([]) List<Tag> tags,
    @Default([]) List<Link> links,
    @Default([]) List<ParsedPosting> postings,
  }) = _ParsedTransaction;
}
