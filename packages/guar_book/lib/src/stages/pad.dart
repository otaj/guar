// Insert pad transactions to satisfy subsequent balance assertions.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/stage_result.dart';
import 'package:guar_domain/guar_domain.dart';

StageResult applyPad(List<Directive> directives, LedgerOptions options, ProcessingInfo info) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Map<String, Inventory> balances = <String, Inventory>{};
  final List<Directive> out = <Directive>[];
  final Decimal multiplier = options.inferredToleranceMultiplier.value;

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
        // Per currency: shortfall at the first failing assertion between this pad
        // and the next pad for the account, including intervening transactions.
        final Map<String, Decimal> flowed = <String, Decimal>{};
        final Map<String, ({BalanceBody balance, Decimal diff})> shortfall =
            <String, ({BalanceBody balance, Decimal diff})>{};
        for (int j = index + 1; j < directives.length; j++) {
          final DirectiveBody laterBody = directives[j].body;
          if (laterBody is PadBody && laterBody.account == account) {
            break;
          }
          switch (laterBody) {
            case TransactionBody(:final Transaction value):
              for (final Posting posting in value.postings) {
                if (posting.account != account) {
                  continue;
                }
                final String currency = posting.units.currency.name;
                flowed[currency] = (flowed[currency] ?? Decimal.zero) + posting.units.number;
              }
            case BalanceBody(account: final Account laterAccount, :final Amount amount, :final Decimal? tolerance):
              if (laterAccount != account) {
                continue;
              }
              final String currency = amount.currency.name;
              if (shortfall.containsKey(currency)) {
                continue;
              }
              final Inventory current = balances[account.name] ?? const Inventory();
              final Decimal have = current.currencyUnits(amount.currency).number + (flowed[currency] ?? Decimal.zero);
              final Decimal diff = amount.number - have;
              final Decimal allowed = tolerance ?? _inferredTolerance(amount.scale, multiplier);
              if (diff.abs() > allowed) {
                shortfall[currency] = (balance: directives[j].body as BalanceBody, diff: diff);
              }
            default:
              break;
          }
        }
        for (final ({BalanceBody balance, Decimal diff}) entry in shortfall.values) {
          Transaction padTransaction(Origin origin) => Transaction(
            origin: origin,
            flag: Flag.letter('P'),
            narration: '(Padding inserted for Balance of ${entry.balance.amount} for difference ${entry.diff})',
            postings: <Posting>[
              Posting(
                origin: origin,
                account: account,
                units: Amount(
                  number: entry.diff,
                  currency: entry.balance.amount.currency,
                  scale: entry.balance.amount.scale,
                ),
              ),
              Posting(
                origin: origin,
                account: sourceAccount,
                units: Amount(
                  number: -entry.diff,
                  currency: entry.balance.amount.currency,
                  scale: entry.balance.amount.scale,
                ),
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
                  units: Amount(
                    number: entry.diff,
                    currency: entry.balance.amount.currency,
                    scale: entry.balance.amount.scale,
                  ),
                ),
              )
              .inventory;
          final Inventory source = balances[sourceAccount.name] ?? const Inventory();
          balances[sourceAccount.name] = source
              .addPosition(
                Position(
                  units: Amount(
                    number: -entry.diff,
                    currency: entry.balance.amount.currency,
                    scale: entry.balance.amount.scale,
                  ),
                ),
              )
              .inventory;
        }
      default:
        break;
    }
  }

  return StageResult(directives: out, errors: errors);
}

Decimal _inferredTolerance(int scale, Decimal multiplier) {
  if (scale <= 0) {
    return Decimal.zero;
  }
  return Decimal.one.shift(-scale) * multiplier;
}
