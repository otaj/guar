// Transaction body after booking and interpolation.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'flag.dart';
import 'origin.dart';
import 'posting.dart';

part 'transaction.freezed.dart';

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required Origin origin,
    required Flag flag,
    String? payee,
    @Default('') String narration,
    @Default([]) List<Tag> tags,
    @Default([]) List<Link> links,
    @Default([]) List<Posting> postings,
  }) = _Transaction;
}
