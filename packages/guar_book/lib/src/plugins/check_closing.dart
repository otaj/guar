// Expand a posting's `closing: TRUE` metadata into a zero balance assertion.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'helpers.dart';

const _closingField = 'closing';

BookPluginResult checkClosing(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final out = <Directive>[];
  for (final directive in directives) {
    final body = directive.body;
    if (body is! TransactionBody) {
      out.add(directive);
      continue;
    }

    final postings = <Posting>[];
    final balances = <Directive>[];
    for (final posting in body.value.postings) {
      if (metaLookup(posting.meta, _closingField) != const MetaValue.boolean(true)) {
        postings.add(posting);
        continue;
      }
      postings.add(posting.copyWith(meta: metaWithout(posting.meta, _closingField)));
      balances.add(
        Directive(
          origin: const Origin.generated(),
          date: nextDay(directive.date),
          body: DirectiveBody.balance(
            account: posting.account,
            amount: Amount(number: Decimal.zero, currency: posting.units.currency),
          ),
        ),
      );
    }

    out.addAll(balances);
    out.add(directive.copyWith(body: DirectiveBody.transaction(body.value.copyWith(postings: postings))));
  }
  return (directives: out, errors: const []);
}
