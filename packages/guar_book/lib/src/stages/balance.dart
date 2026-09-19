// Check balance assertions against running inventories.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/stage_result.dart';
import 'package:guar_domain/guar_domain.dart';

StageResult applyBalance(List<Directive> directives, LedgerOptions options) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Map<String, Inventory> balances = <String, Inventory>{};
  final Decimal multiplier = options.inferredToleranceMultiplier.value;

  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    switch (body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          final Inventory current = balances[posting.account.name] ?? const Inventory();
          balances[posting.account.name] = current
              .addPosition(Position(units: posting.units, cost: posting.cost))
              .inventory;
          // Parent accounts accumulate child postings for parent balance checks.
          for (final String parentName in _parentNames(posting.account)) {
            final Inventory parentInv = balances[parentName] ?? const Inventory();
            balances[parentName] = parentInv.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
          }
        }
      case BalanceBody(:final Account account, :final Amount amount, :final Decimal? tolerance):
        final Decimal have = (balances[account.name] ?? const Inventory()).currencyUnits(amount.currency).number;
        final Decimal diff = (have - amount.number).abs();
        final Decimal allowed = tolerance ?? _inferredTolerance(amount.scale, multiplier);
        if (diff > allowed) {
          final BeanLocation location = switch (directive.origin) {
            SourceOrigin(:final BeanLocation location) => location,
            GeneratedOrigin() => BeanLocation(linenoBegin: 0, linenoEnd: 0),
          };
          errors.add(
            ProcessingError(
              message: 'Balance failed for "${account.name}": expected $amount != accumulated $have',
              location: location,
            ),
          );
        }
      default:
        break;
    }
  }

  return StageResult(directives: directives, errors: errors);
}

Decimal _inferredTolerance(int scale, Decimal multiplier) {
  if (scale <= 0) {
    return Decimal.zero;
  }
  return Decimal.one.shift(-scale) * multiplier;
}

Iterable<String> _parentNames(Account account) sync* {
  final List<String> parts = account.name.split(':');
  for (int i = 1; i < parts.length; i++) {
    yield parts.sublist(0, i).join(':');
  }
}
