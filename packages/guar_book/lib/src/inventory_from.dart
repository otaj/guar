// Build a LedgerInventory by replaying booked transaction postings.

import 'package:guar_domain/guar_domain.dart';

LedgerInventory inventoryFromLedger(Ledger ledger) => switch (ledger) {
  LedgerErrors() => const LedgerInventory(),
  LedgerDirectives(:final List<Directive> directives) => inventoryFromDirectives(directives),
};

LedgerInventory inventoryFromDirectives(Iterable<Directive> directives) {
  LedgerInventory inventory = const LedgerInventory();
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! TransactionBody) {
      continue;
    }
    for (final Posting posting in body.value.postings) {
      inventory = inventory.addPosition(posting.account, Position(units: posting.units, cost: posting.cost));
    }
  }
  return inventory;
}

String formatLedgerInventory(LedgerInventory inventory) {
  final StringBuffer buffer = StringBuffer();
  for (final AccountInventory entry in inventory.accounts) {
    final String account = entry.account.name;
    final List<Position> positions = entry.inventory.positions;
    if (positions.isEmpty) {
      continue;
    }
    for (int i = 0; i < positions.length; i++) {
      final Position position = positions[i];
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
  final Cost cost = position.cost!;
  final String date = '${cost.date}';
  return '${position.units.number} ${position.units.currency.name} {$date ${cost.currency.name} ${cost.number}}';
}
