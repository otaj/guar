// Strict lot-matching bag of positions.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/cost.dart';
import 'package:guar_domain/src/position.dart';

part 'inventory.freezed.dart';

enum MatchResult { created, reduced, augmented, ignored }

@freezed
abstract class InventoryAdd with _$InventoryAdd {
  const factory InventoryAdd({required Inventory inventory, required MatchResult result, Position? previous}) =
      _InventoryAdd;
}

@freezed
abstract class Inventory with _$Inventory {
  const factory Inventory({@Default(<Position>[]) List<Position> positions}) = _Inventory;
  const Inventory._();

  bool get isEmpty => positions.isEmpty;

  int get length => positions.length;

  @override
  String toString() => '(${positions.map((Position p) => p.toString()).join(', ')})';

  Inventory operator -() => Inventory(positions: <Position>[for (final Position position in positions) -position]);

  Inventory operator *(Decimal scalar) =>
      Inventory(positions: <Position>[for (final Position position in positions) position * scalar]);

  Inventory get absolute =>
      Inventory(positions: <Position>[for (final Position position in positions) position.absolute]);

  Amount currencyUnits(Currency currency) {
    Decimal total = Decimal.zero;
    for (final Position position in positions) {
      if (position.units.currency == currency) {
        total += position.units.number;
      }
    }
    return Amount(number: total, currency: currency);
  }

  Set<String> currencies() => <String>{for (final Position position in positions) position.units.currency.name};

  bool get isMixed {
    final Map<String, bool> signs = <String, bool>{};
    for (final Position position in positions) {
      final bool sign = position.units.number >= Decimal.zero;
      final bool? previous = signs[position.units.currency.name];
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

    final int index = positions.indexWhere(
      (Position position) => position.units.currency == units.currency && position.cost == cost,
    );

    if (index < 0) {
      final List<Position> next = <Position>[...positions, Position(units: units, cost: cost)]..sort(Position.compare);
      return InventoryAdd(
        inventory: Inventory(positions: next),
        result: MatchResult.created,
      );
    }

    final Position existing = positions[index];
    final MatchResult booking = !_sameSign(existing.units.number, units.number)
        ? MatchResult.reduced
        : MatchResult.augmented;
    final Decimal number = existing.units.number + units.number;
    if (number == Decimal.zero) {
      return InventoryAdd(
        inventory: Inventory(positions: <Position>[...positions]..removeAt(index)),
        result: booking,
        previous: existing,
      );
    }

    final List<Position> updated = <Position>[...positions];
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
    Inventory result = this;
    for (final Position position in other.positions) {
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
  const factory LedgerInventory({@Default(<AccountInventory>[]) List<AccountInventory> accounts}) = _LedgerInventory;
  const LedgerInventory._();

  LedgerInventory addPosition(Account account, Position position) {
    final int index = accounts.indexWhere((AccountInventory entry) => entry.account == account);
    if (index < 0) {
      final List<AccountInventory> next = <AccountInventory>[
        ...accounts,
        AccountInventory(account: account, inventory: const Inventory().addPosition(position).inventory),
      ]..sort((AccountInventory a, AccountInventory b) => a.account.name.compareTo(b.account.name));
      return LedgerInventory(accounts: next);
    }
    final List<AccountInventory> updated = <AccountInventory>[...accounts];
    updated[index] = AccountInventory(
      account: account,
      inventory: accounts[index].inventory.addPosition(position).inventory,
    );
    return LedgerInventory(accounts: updated);
  }

  Inventory? inventoryFor(Account account) {
    for (final AccountInventory entry in accounts) {
      if (entry.account == account) {
        return entry.inventory;
      }
    }
    return null;
  }

  Inventory inventoryUnder(Account account) {
    Inventory result = const Inventory();
    for (final AccountInventory entry in accounts) {
      if (entry.account == account || entry.account.isSubaccountOf(account)) {
        result = result.addInventory(entry.inventory);
      }
    }
    return result;
  }
}
