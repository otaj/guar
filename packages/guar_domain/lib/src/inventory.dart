// Strict lot-matching bag of positions.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'cost.dart';
import 'position.dart';

part 'inventory.freezed.dart';

enum MatchResult { created, reduced, augmented, ignored }

@freezed
abstract class InventoryAdd with _$InventoryAdd {
  const factory InventoryAdd({required Inventory inventory, required MatchResult result, Position? previous}) =
      _InventoryAdd;
}

@freezed
abstract class Inventory with _$Inventory {
  const Inventory._();

  const factory Inventory({@Default([]) List<Position> positions}) = _Inventory;

  bool get isEmpty => positions.isEmpty;

  int get length => positions.length;

  @override
  String toString() => '(${positions.map((p) => p.toString()).join(', ')})';

  Inventory operator -() => Inventory(positions: [for (final position in positions) -position]);

  Inventory operator *(Decimal scalar) => Inventory(positions: [for (final position in positions) position * scalar]);

  Inventory get absolute => Inventory(positions: [for (final position in positions) position.absolute]);

  Amount currencyUnits(Currency currency) {
    var total = Decimal.zero;
    for (final position in positions) {
      if (position.units.currency == currency) {
        total += position.units.number;
      }
    }
    return Amount(number: total, currency: currency);
  }

  Set<String> currencies() => {for (final position in positions) position.units.currency.name};

  bool get isMixed {
    final signs = <String, bool>{};
    for (final position in positions) {
      final sign = position.units.number >= Decimal.zero;
      final previous = signs[position.units.currency.name];
      if (previous != null && previous != sign) {
        return true;
      }
      signs[position.units.currency.name] = sign;
    }
    return false;
  }

  InventoryAdd addAmount(Amount units, {Cost? cost}) {
    if (units.number == Decimal.zero) {
      return InventoryAdd(inventory: this, result: MatchResult.ignored);
    }

    final index = positions.indexWhere(
      (position) => position.units.currency == units.currency && position.cost == cost,
    );

    if (index < 0) {
      final next = [...positions, Position(units: units, cost: cost)];
      next.sort(Position.compare);
      return InventoryAdd(
        inventory: Inventory(positions: next),
        result: MatchResult.created,
      );
    }

    final existing = positions[index];
    final booking = !_sameSign(existing.units.number, units.number) ? MatchResult.reduced : MatchResult.augmented;
    final number = existing.units.number + units.number;
    if (number == Decimal.zero) {
      return InventoryAdd(
        inventory: Inventory(positions: [...positions]..removeAt(index)),
        result: booking,
        previous: existing,
      );
    }

    final updated = [...positions];
    updated[index] = Position(
      units: Amount(number: number, currency: units.currency),
      cost: cost,
    );
    updated.sort(Position.compare);
    return InventoryAdd(
      inventory: Inventory(positions: updated),
      result: booking,
      previous: existing,
    );
  }

  InventoryAdd addPosition(Position position) => addAmount(position.units, cost: position.cost);

  Inventory addInventory(Inventory other) {
    var result = this;
    for (final position in other.positions) {
      result = result.addPosition(position).inventory;
    }
    return result;
  }

  static bool _sameSign(Decimal left, Decimal right) => (left >= Decimal.zero) == (right >= Decimal.zero);
}

@freezed
abstract class AccountInventory with _$AccountInventory {
  const factory AccountInventory({required Account account, @Default(Inventory()) Inventory inventory}) =
      _AccountInventory;
}

@freezed
abstract class LedgerInventory with _$LedgerInventory {
  const LedgerInventory._();

  const factory LedgerInventory({@Default([]) List<AccountInventory> accounts}) = _LedgerInventory;

  LedgerInventory addPosition(Account account, Position position) {
    final index = accounts.indexWhere((entry) => entry.account == account);
    if (index < 0) {
      final next = [
        ...accounts,
        AccountInventory(account: account, inventory: Inventory().addPosition(position).inventory),
      ]..sort((a, b) => a.account.name.compareTo(b.account.name));
      return LedgerInventory(accounts: next);
    }
    final updated = [...accounts];
    updated[index] = AccountInventory(
      account: account,
      inventory: accounts[index].inventory.addPosition(position).inventory,
    );
    return LedgerInventory(accounts: updated);
  }

  Inventory? inventoryFor(Account account) {
    for (final entry in accounts) {
      if (entry.account == account) {
        return entry.inventory;
      }
    }
    return null;
  }

  Inventory inventoryUnder(Account account) {
    var result = const Inventory();
    for (final entry in accounts) {
      if (entry.account == account || entry.account.isSubaccountOf(account)) {
        result = result.addInventory(entry.inventory);
      }
    }
    return result;
  }
}
