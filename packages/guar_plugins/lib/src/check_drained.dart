// Assert a zero balance the day after a balance-sheet account is closed.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult checkDrained(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final Map<String, Set<String>> currencies = <String, Set<String>>{};
  final List<Directive> out = <Directive>[];

  // Collected up front: the parser orders same-day closes before balances.
  final Set<String> balances = <String>{};
  for (final Directive directive in directives) {
    if (directive.body case BalanceBody(
      :final Account account,
      :final Amount amount,
    ) when isBalanceSheetAccount(account)) {
      balances.add('${account.name}|${directive.date}|${amount.currency.name}');
    }
  }

  for (final Directive directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          if (isBalanceSheetAccount(posting.account)) {
            currencies.putIfAbsent(posting.account.name, () => <String>{}).add(posting.units.currency.name);
          }
        }
      case OpenBody(:final Account account, currencies: final List<Currency> declared):
        if (isBalanceSheetAccount(account) && declared.isNotEmpty) {
          currencies
              .putIfAbsent(account.name, () => <String>{})
              .addAll(declared.map((Currency currency) => currency.name));
        }
      default:
        break;
    }

    if (directive.body case CloseBody(:final Account account) when isBalanceSheetAccount(account)) {
      final String dateKey = '${directive.date}';
      final Set<String> seen = currencies[account.name] ?? const <String>{};
      for (final String currency in seen) {
        if (balances.contains('${account.name}|$dateKey|$currency')) continue;
        out.add(
          Directive(
            origin: insertOrigin(
              date: addDays(directive.date, 1),
              body: DirectiveBody.balance(
                account: account,
                amount: Amount(
                  number: Decimal.zero,
                  currency: Currency(name: currency),
                ),
              ),
              existing: directives,
              info: info,
            ),
            date: addDays(directive.date, 1),
            body: DirectiveBody.balance(
              account: account,
              amount: Amount(
                number: Decimal.zero,
                currency: Currency(name: currency),
              ),
            ),
          ),
        );
      }
    }

    out.add(directive);
  }
  return (directives: out, errors: const <ProcessingError>[]);
}
