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
    @Default(<Tag>[]) List<Tag> tags,
    @Default(<Link>[]) List<Link> links,
    @Default(<Posting>[]) List<Posting> postings,
  }) = _Transaction;
}
