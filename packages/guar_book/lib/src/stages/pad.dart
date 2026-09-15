// Insert pad transactions to satisfy subsequent balance assertions.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../stage_result.dart';

StageResult applyPad(List<Directive> directives, LedgerOptions options) {
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
        // Look ahead for the next balance on this account.
        BalanceBody? nextBalance;
        for (final later in directives.skip(directives.indexOf(directive) + 1)) {
          final laterBody = later.body;
          if (laterBody is PadBody && laterBody.account == account) {
            break;
          }
          if (laterBody is BalanceBody && laterBody.account == account) {
            nextBalance = laterBody;
            break;
          }
        }
        if (nextBalance == null) {
          continue;
        }
        final current = balances[account.name] ?? const Inventory();
        final have = current.currencyUnits(nextBalance.amount.currency).number;
        final want = nextBalance.amount.number;
        final diff = want - have;
        if (diff == Decimal.zero) {
          continue;
        }
        final padTxn = Directive(
          origin: const Origin.generated(),
          date: directive.date,
          body: DirectiveBody.transaction(
            Transaction(
              origin: const Origin.generated(),
              flag: const Flag.special(SpecialFlag.asterisk),
              narration: '(Padding inserted for Balance of ${nextBalance.amount} for difference $diff)',
              postings: [
                Posting(
                  origin: const Origin.generated(),
                  account: account,
                  units: Amount(number: diff, currency: nextBalance.amount.currency),
                ),
                Posting(
                  origin: const Origin.generated(),
                  account: sourceAccount,
                  units: Amount(number: -diff, currency: nextBalance.amount.currency),
                ),
              ],
            ),
          ),
        );
        out.add(padTxn);
        final padded = balances[account.name] ?? const Inventory();
        balances[account.name] = padded
            .addPosition(
              Position(
                units: Amount(number: diff, currency: nextBalance.amount.currency),
              ),
            )
            .inventory;
        final source = balances[sourceAccount.name] ?? const Inventory();
        balances[sourceAccount.name] = source
            .addPosition(
              Position(
                units: Amount(number: -diff, currency: nextBalance.amount.currency),
              ),
            )
            .inventory;
      default:
        break;
    }
  }

  return StageResult(directives: out, errors: errors);
}
