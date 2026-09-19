// Transaction body after booking and interpolation.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/flag.dart';
import 'package:guar_domain/src/origin.dart';
import 'package:guar_domain/src/posting.dart';

part 'transaction.freezed.dart';

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required Origin origin,
    required Flag flag,
    String? payee,
    @Default('') String narration,
    @Default(<dynamic>[]) List<Tag> tags,
    @Default(<dynamic>[]) List<Link> links,
    @Default(<dynamic>[]) List<Posting> postings,
  }) = _Transaction;
}
