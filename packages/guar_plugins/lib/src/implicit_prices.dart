// Synthesize Price directives from posting prices and non-reducing costs.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';

const String _implicitPricesField = '__implicit_prices__';

BookPluginResult addImplicitPrices(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final List<Directive> out = <Directive>[];
  final Set<String> seen = <String>{};
  final Map<String, Inventory> balances = <String, Inventory>{};

  for (final Directive directive in directives) {
    out.add(directive);
    final DirectiveBody body = directive.body;
    if (body is! TransactionBody) continue;

    for (final Posting posting in body.value.postings) {
      final Amount units = posting.units;
      final Cost? cost = posting.cost;
      final Inventory balance = balances[posting.account.name] ?? const Inventory();
      final InventoryAdd added = balance.addPosition(Position(units: units, cost: cost));
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
      final PriceBody priceBody = priceEntry.body as PriceBody;
      final String key =
          '${priceEntry.date}|'
          '${priceBody.currency.name}|${priceBody.amount.number}|${priceBody.amount.currency.name}';
      if (seen.add(key)) {
        out.add(priceEntry);
      }
    }
  }

  return (directives: out, errors: const <ProcessingError>[]);
}

Directive _priceDirective({
  required BeanDate date,
  required Currency currency,
  required Amount amount,
  required String tag,
  required List<Directive> existing,
  required ProcessingInfo info,
}) {
  final DirectiveBody body = DirectiveBody.price(currency: currency, amount: amount);
  return Directive(
    origin: insertOrigin(date: date, body: body, existing: existing, info: info),
    date: date,
    meta: Meta(
      entries: <MetaEntry>[MetaEntry(key: _implicitPricesField, value: MetaValue.text(tag))],
    ),
    body: body,
  );
}
