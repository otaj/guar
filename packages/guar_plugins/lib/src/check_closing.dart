// Expand a posting's `closing: TRUE` metadata into a zero balance assertion.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

const String _closingField = 'closing';

BookPluginResult checkClosing(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final List<Directive> out = <Directive>[];
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! TransactionBody) {
      out.add(directive);
      continue;
    }

    final List<Posting> postings = <Posting>[];
    final List<Directive> balances = <Directive>[];
    for (final Posting posting in body.value.postings) {
      if (posting.meta.lookup(_closingField) != const MetaValue.boolean(true)) {
        postings.add(posting);
        continue;
      }
      postings.add(posting.copyWith(meta: metaWithout(posting.meta, _closingField)));
      balances.add(
        Directive(
          origin: insertOrigin(
            date: addDays(directive.date, 1),
            body: DirectiveBody.balance(
              account: posting.account,
              amount: Amount(number: Decimal.zero, currency: posting.units.currency),
            ),
            existing: directives,
            info: info,
          ),
          date: addDays(directive.date, 1),
          body: DirectiveBody.balance(
            account: posting.account,
            amount: Amount(number: Decimal.zero, currency: posting.units.currency),
          ),
        ),
      );
    }

    out
      ..addAll(balances)
      ..add(directive.copyWith(body: DirectiveBody.transaction(body.value.copyWith(postings: postings))));
  }
  return (directives: out, errors: const <ProcessingError>[]);
}
