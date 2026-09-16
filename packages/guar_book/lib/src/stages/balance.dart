// Check balance assertions against running inventories.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../stage_result.dart';

StageResult applyBalance(List<Directive> directives, LedgerOptions options) {
  final errors = <ProcessingError>[];
  final balances = <String, Inventory>{};
  final multiplier = options.toleranceMultiplier ?? Decimal.parse('0.5');

  for (final directive in directives) {
    final body = directive.body;
    switch (body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          final current = balances[posting.account.name] ?? const Inventory();
          balances[posting.account.name] = current
              .addPosition(Position(units: posting.units, cost: posting.cost))
              .inventory;
          // Parent accounts accumulate child postings for parent balance checks.
          for (final parentName in _parentNames(posting.account)) {
            final parentInv = balances[parentName] ?? const Inventory();
            balances[parentName] = parentInv.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
          }
        }
      case BalanceBody(:final account, :final amount, :final tolerance):
        final have = (balances[account.name] ?? const Inventory()).currencyUnits(amount.currency).number;
        final diff = (have - amount.number).abs();
        final allowed = tolerance ?? _inferredTolerance(amount.scale, multiplier);
        if (diff > allowed) {
          final location = switch (directive.origin) {
            SourceOrigin(:final location) => location,
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
  final parts = account.name.split(':');
  for (var i = 1; i < parts.length; i++) {
    yield parts.sublist(0, i).join(':');
  }
}
