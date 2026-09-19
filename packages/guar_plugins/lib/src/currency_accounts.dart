// Neutralize currency conversions into per-currency trading accounts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

const String _metaProcessed = 'currency_accounts_processed';
const String _defaultBaseAccount = 'Equity:CurrencyAccounts';
final RegExp _accountRe = RegExp(r'^[A-Z][A-Za-z0-9\-]*(?::[A-Z0-9][A-Za-z0-9\-]*)+$');

BookPluginResult insertCurrencyTradingPostings(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  String baseAccount = (config ?? '').trim();
  if (!_accountRe.hasMatch(baseAccount)) {
    baseAccount = _defaultBaseAccount;
  }

  final Set<String> newAccounts = <String>{};
  final List<Directive> out = <Directive>[];
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is TransactionBody) {
      final ({Map<String, List<Posting>> groups, bool hasPrice}) grouped = _groupByWeightCurrency(body.value.postings);
      if (grouped.hasPrice && grouped.groups.length > 1) {
        out.add(
          directive.copyWith(
            meta: Meta(
              entries: <MetaEntry>[
                ...directive.meta.entries,
                const MetaEntry(key: _metaProcessed, value: MetaValue.boolean(true)),
              ],
            ),
            body: DirectiveBody.transaction(
              body.value.copyWith(postings: _neutralizingPostings(grouped.groups, baseAccount, newAccounts, options)),
            ),
          ),
        );
        continue;
      }
    }
    out.add(directive);
  }

  if (directives.isEmpty || newAccounts.isEmpty) {
    return (directives: out, errors: const <ProcessingError>[]);
  }
  final BeanDate earliest = directives.first.date;
  final List<Directive> opens = <Directive>[
    for (final String name in newAccounts.toList()..sort())
      Directive(
        origin: insertOrigin(
          date: earliest,
          body: DirectiveBody.open(account: generatedAccount(name, options)),
          existing: directives,
          info: info,
        ),
        date: earliest,
        body: DirectiveBody.open(account: generatedAccount(name, options)),
      ),
  ];
  return (directives: <Directive>[...opens, ...out], errors: const <ProcessingError>[]);
}

({Map<String, List<Posting>> groups, bool hasPrice}) _groupByWeightCurrency(List<Posting> postings) {
  final Map<String, List<Posting>> groups = <String, List<Posting>>{};
  bool hasPrice = false;
  for (final Posting posting in postings) {
    final Cost? cost = posting.cost;
    final String currency = cost != null ? cost.currency.name : posting.units.currency.name;
    if (posting.price != null) {
      hasPrice = true;
    }
    groups.putIfAbsent(currency, () => <Posting>[]).add(posting);
  }
  return (groups: groups, hasPrice: hasPrice);
}

List<Posting> _neutralizingPostings(
  Map<String, List<Posting>> groups,
  String baseAccount,
  Set<String> newAccounts,
  LedgerOptions options,
) {
  final List<Posting> out = <Posting>[];
  for (final MapEntry<String, List<Posting>> entry in groups.entries) {
    Decimal total = Decimal.zero;
    for (final Posting posting in entry.value) {
      final Cost? cost = posting.cost;
      total += cost != null ? posting.units.number * cost.number : posting.units.number;
    }
    if (total == Decimal.zero) {
      out.addAll(entry.value);
      continue;
    }
    for (final Posting posting in entry.value) {
      out.add(posting.price == null ? posting : posting.copyWith(price: null));
    }
    final String name = '$baseAccount:${entry.key}';
    newAccounts.add(name);
    out.add(
      Posting(
        origin: const Origin.generated(),
        account: generatedAccount(name, options),
        units: Amount(
          number: -total,
          currency: Currency(name: entry.key),
        ),
      ),
    );
  }
  return out;
}
