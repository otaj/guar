// Neutralize currency conversions into per-currency trading accounts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

const _metaProcessed = 'currency_accounts_processed';
const _defaultBaseAccount = 'Equity:CurrencyAccounts';
final RegExp _accountRe = RegExp(r'^[A-Z][A-Za-z0-9\-]*(?::[A-Z0-9][A-Za-z0-9\-]*)+$');

BookPluginResult insertCurrencyTradingPostings(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  var baseAccount = (config ?? '').trim();
  if (!_accountRe.hasMatch(baseAccount)) {
    baseAccount = _defaultBaseAccount;
  }

  final newAccounts = <String>{};
  final out = <Directive>[];
  for (final directive in directives) {
    final body = directive.body;
    if (body is TransactionBody) {
      final grouped = _groupByWeightCurrency(body.value.postings);
      if (grouped.hasPrice && grouped.groups.length > 1) {
        out.add(
          directive.copyWith(
            meta: Meta(
              entries: [
                ...directive.meta.entries,
                MetaEntry(key: _metaProcessed, value: MetaValue.boolean(true)),
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
    return (directives: out, errors: const []);
  }
  final earliest = directives.first.date;
  final opens = [
    for (final name in newAccounts.toList()..sort())
      Directive(
        origin: const Origin.generated(),
        date: earliest,
        body: DirectiveBody.open(account: generatedAccount(name, options)),
      ),
  ];
  return (directives: [...opens, ...out], errors: const []);
}

({Map<String, List<Posting>> groups, bool hasPrice}) _groupByWeightCurrency(List<Posting> postings) {
  final groups = <String, List<Posting>>{};
  var hasPrice = false;
  for (final posting in postings) {
    final cost = posting.cost;
    final currency = cost != null ? cost.currency.name : posting.units.currency.name;
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
  final out = <Posting>[];
  for (final entry in groups.entries) {
    var total = Decimal.zero;
    for (final posting in entry.value) {
      final cost = posting.cost;
      total += cost != null ? posting.units.number * cost.number : posting.units.number;
    }
    if (total == Decimal.zero) {
      out.addAll(entry.value);
      continue;
    }
    for (final posting in entry.value) {
      out.add(posting.price == null ? posting : posting.copyWith(price: null));
    }
    final name = '$baseAccount:${entry.key}';
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
