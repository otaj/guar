// Insert pad transactions to satisfy subsequent balance assertions.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../stage_result.dart';

StageResult applyPad(List<Directive> directives, LedgerOptions options, ProcessingInfo info) {
  final errors = <ProcessingError>[];
  final balances = <String, Inventory>{};
  final out = <Directive>[];

  for (final directive in directives) {
    out.add(directive);
    final body = directive.body;
    switch (body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          final current = balances[posting.account.name] ?? const Inventory();
          balances[posting.account.name] = current
              .addPosition(Position(units: posting.units, cost: posting.cost))
              .inventory;
        }
      case PadBody(:final account, :final sourceAccount):
        final index = directives.indexOf(directive);
        BalanceBody? nextBalance;
        var end = directives.length;
        for (var j = index + 1; j < directives.length; j++) {
          final laterBody = directives[j].body;
          if (laterBody is PadBody && laterBody.account == account) {
            end = j;
            break;
          }
          if (laterBody is BalanceBody && laterBody.account == account) {
            nextBalance = laterBody;
            end = j;
            break;
          }
        }
        if (nextBalance == null) {
          continue;
        }
        final current = balances[account.name] ?? const Inventory();
        var have = current.currencyUnits(nextBalance.amount.currency).number;
        for (var j = index + 1; j < end; j++) {
          final laterBody = directives[j].body;
          if (laterBody is! TransactionBody) continue;
          for (final posting in laterBody.value.postings) {
            if (posting.account == account && posting.units.currency == nextBalance.amount.currency) {
              have += posting.units.number;
            }
          }
        }
        final want = nextBalance.amount.number;
        final diff = want - have;
        if (diff == Decimal.zero) {
          continue;
        }
        final balance = nextBalance;
        Transaction padTransaction(Origin origin) => Transaction(
          origin: origin,
          flag: Flag.letter('P'),
          narration: '(Padding inserted for Balance of ${balance.amount} for difference $diff)',
          postings: [
            Posting(
              origin: origin,
              account: account,
              units: Amount(number: diff, currency: balance.amount.currency, scale: balance.amount.scale),
            ),
            Posting(
              origin: origin,
              account: sourceAccount,
              units: Amount(number: -diff, currency: balance.amount.currency, scale: balance.amount.scale),
            ),
          ],
        );
        final origin = insertOrigin(
          date: directive.date,
          body: DirectiveBody.transaction(padTransaction(const Origin.generated())),
          existing: directives,
          info: info,
        );
        final padTxn = Directive(
          origin: origin,
          date: directive.date,
          body: DirectiveBody.transaction(padTransaction(origin)),
        );
        out.add(padTxn);
        final padded = balances[account.name] ?? const Inventory();
        balances[account.name] = padded
            .addPosition(
              Position(
                units: Amount(number: diff, currency: nextBalance.amount.currency, scale: nextBalance.amount.scale),
              ),
            )
            .inventory;
        final source = balances[sourceAccount.name] ?? const Inventory();
        balances[sourceAccount.name] = source
            .addPosition(
              Position(
                units: Amount(number: -diff, currency: nextBalance.amount.currency, scale: nextBalance.amount.scale),
              ),
            )
            .inventory;
      default:
        break;
    }
  }

  return StageResult(directives: out, errors: errors);
}
