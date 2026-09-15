// Build a LedgerInventory by replaying booked transaction postings.

import 'package:guar_domain/guar_domain.dart';

LedgerInventory inventoryFromLedger(Ledger ledger) {
  return switch (ledger) {
    LedgerErrors() => LedgerInventory(),
    LedgerDirectives(:final directives) => inventoryFromDirectives(directives),
  };
}

LedgerInventory inventoryFromDirectives(Iterable<Directive> directives) {
  var inventory = LedgerInventory();
  for (final directive in directives) {
    final body = directive.body;
    if (body is! TransactionBody) {
      continue;
    }
    for (final posting in body.value.postings) {
      inventory = inventory.addPosition(posting.account, Position(units: posting.units, cost: posting.cost));
    }
  }
  return inventory;
}

String formatLedgerInventory(LedgerInventory inventory) {
  final buffer = StringBuffer();
  for (final entry in inventory.accounts) {
    final account = entry.account.name;
    final positions = entry.inventory.positions;
    if (positions.isEmpty) {
      continue;
    }
    for (var i = 0; i < positions.length; i++) {
      final position = positions[i];
      if (i == 0) {
        buffer.writeln('$account\t${_formatPosition(position)}');
      } else {
        buffer.writeln('${''.padRight(account.length)}\t${_formatPosition(position)}');
      }
    }
  }
  return buffer.toString().trimRight();
}

String _formatPosition(Position position) {
  if (position.cost == null) {
    return '${position.units.number} ${position.units.currency.name}';
  }
  final cost = position.cost!;
  final date = '${cost.date}';
  return '${position.units.number} ${position.units.currency.name} {$date ${cost.currency.name} ${cost.number}}';
}
