// Synthesize Price directives from posting prices and non-reducing costs.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';

const _implicitPricesField = '__implicit_prices__';

BookPluginResult addImplicitPrices(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final out = <Directive>[];
  final seen = <String>{};
  final balances = <String, Inventory>{};

  for (final directive in directives) {
    out.add(directive);
    final body = directive.body;
    if (body is! TransactionBody) continue;

    for (final posting in body.value.postings) {
      final units = posting.units;
      final cost = posting.cost;
      final balance = balances[posting.account.name] ?? const Inventory();
      final added = balance.addPosition(Position(units: units, cost: cost));
      balances[posting.account.name] = added.inventory;

      Directive? priceEntry;
      if (posting.price != null) {
        priceEntry = _priceDirective(
          date: directive.date,
          currency: units.currency,
          amount: posting.price!,
          tag: 'from_price',
          existing: directives,
          info: info,
        );
      } else if (cost != null && added.result != MatchResult.reduced) {
        priceEntry = _priceDirective(
          date: directive.date,
          currency: units.currency,
          amount: Amount(number: cost.number, currency: cost.currency),
          tag: 'from_cost',
          existing: directives,
          info: info,
        );
      }

      if (priceEntry == null) continue;
      final priceBody = priceEntry.body as PriceBody;
      final key =
          '${priceEntry.date}|'
          '${priceBody.currency.name}|${priceBody.amount.number}|${priceBody.amount.currency.name}';
      if (seen.add(key)) {
        out.add(priceEntry);
      }
    }
  }

  return (directives: out, errors: const []);
}

Directive _priceDirective({
  required BeanDate date,
  required Currency currency,
  required Amount amount,
  required String tag,
  required List<Directive> existing,
  required ProcessingInfo info,
}) {
  final body = DirectiveBody.price(currency: currency, amount: amount);
  return Directive(
    origin: insertOrigin(date: date, body: body, existing: existing, info: info),
    date: date,
    meta: Meta(
      entries: [MetaEntry(key: _implicitPricesField, value: MetaValue.text(tag))],
    ),
    body: body,
  );
}
