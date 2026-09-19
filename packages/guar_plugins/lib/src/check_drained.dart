// Assert a zero balance the day after a balance-sheet account is closed.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'helpers.dart';

BookPluginResult checkDrained(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final currencies = <String, Set<String>>{};
  final out = <Directive>[];

  // Collected up front: the parser orders same-day closes before balances.
  final balances = <String>{};
  for (final directive in directives) {
    if (directive.body case BalanceBody(:final account, :final amount) when isBalanceSheetAccount(account)) {
      balances.add('${account.name}|${directive.date}|${amount.currency.name}');
    }
  }

  for (final directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          if (isBalanceSheetAccount(posting.account)) {
            currencies.putIfAbsent(posting.account.name, () => <String>{}).add(posting.units.currency.name);
          }
        }
      case OpenBody(:final account, currencies: final declared):
        if (isBalanceSheetAccount(account) && declared.isNotEmpty) {
          currencies.putIfAbsent(account.name, () => <String>{}).addAll(declared.map((currency) => currency.name));
        }
      default:
        break;
    }

    if (directive.body case CloseBody(:final account) when isBalanceSheetAccount(account)) {
      final dateKey = '${directive.date}';
      final seen = currencies[account.name] ?? const <String>{};
      for (final currency in seen) {
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
  return (directives: out, errors: const []);
}
