// Insert pad transactions to satisfy subsequent balance assertions.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/stage_result.dart';
import 'package:guar_domain/guar_domain.dart';

StageResult applyPad(List<Directive> directives, LedgerOptions options, ProcessingInfo info) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Map<String, Inventory> balances = <String, Inventory>{};
  final List<Directive> out = <Directive>[];

  for (final Directive directive in directives) {
    out.add(directive);
    final DirectiveBody body = directive.body;
    switch (body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          final Inventory current = balances[posting.account.name] ?? const Inventory();
          balances[posting.account.name] = current
              .addPosition(Position(units: posting.units, cost: posting.cost))
              .inventory;
        }
      case PadBody(:final Account account, :final Account sourceAccount):
        final int index = directives.indexOf(directive);
        BalanceBody? nextBalance;
        int end = directives.length;
        for (int j = index + 1; j < directives.length; j++) {
          final DirectiveBody laterBody = directives[j].body;
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
        final Inventory current = balances[account.name] ?? const Inventory();
        Decimal have = current.currencyUnits(nextBalance.amount.currency).number;
        for (int j = index + 1; j < end; j++) {
          final DirectiveBody laterBody = directives[j].body;
          if (laterBody is! TransactionBody) continue;
          for (final Posting posting in laterBody.value.postings) {
            if (posting.account == account && posting.units.currency == nextBalance.amount.currency) {
              have += posting.units.number;
            }
          }
        }
        final Decimal want = nextBalance.amount.number;
        final Decimal diff = want - have;
        if (diff == Decimal.zero) {
          continue;
        }
        final BalanceBody balance = nextBalance;
        Transaction padTransaction(Origin origin) => Transaction(
          origin: origin,
          flag: Flag.letter('P'),
          narration: '(Padding inserted for Balance of ${balance.amount} for difference $diff)',
          postings: <Posting>[
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
        final Origin origin = insertOrigin(
          date: directive.date,
          body: DirectiveBody.transaction(padTransaction(const Origin.generated())),
          existing: directives,
          info: info,
        );
        final Directive padTxn = Directive(
          origin: origin,
          date: directive.date,
          body: DirectiveBody.transaction(padTransaction(origin)),
        );
        out.add(padTxn);
        final Inventory padded = balances[account.name] ?? const Inventory();
        balances[account.name] = padded
            .addPosition(
              Position(
                units: Amount(number: diff, currency: nextBalance.amount.currency, scale: nextBalance.amount.scale),
              ),
            )
            .inventory;
        final Inventory source = balances[sourceAccount.name] ?? const Inventory();
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
