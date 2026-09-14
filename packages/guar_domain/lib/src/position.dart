// Units of a commodity held at an optional booked cost.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'amount.dart';
import 'cost.dart';

part 'position.freezed.dart';

@freezed
abstract class Position with _$Position {
  const Position._();

  const factory Position({required Amount units, Cost? cost}) = _Position;

  @override
  String toString({bool detail = true}) {
    if (cost == null) {
      return units.toString();
    }
    return '$units {${cost!.toString(detail: detail)}}';
  }

  Position operator -() => Position(units: -units, cost: cost);

  Position operator *(Decimal scalar) => Position(units: Amount.mul(units, scalar), cost: cost);

  Position get absolute => Position(units: Amount.abs(units), cost: cost);

  bool get isNegativeAtCost => units.number < Decimal.zero && cost != null;

  (String, String?) get currencyPair => (units.currency.name, cost?.currency.name);

  static int compare(Position left, Position right) {
    final byCurrency = left.units.currency.name.compareTo(right.units.currency.name);
    if (byCurrency != 0) {
      return byCurrency;
    }
    final leftCost = left.cost?.number ?? Decimal.zero;
    final rightCost = right.cost?.number ?? Decimal.zero;
    final byCost = leftCost.compareTo(rightCost);
    if (byCost != 0) {
      return byCost;
    }
    final leftCostCurrency = left.cost?.currency.name ?? '';
    final rightCostCurrency = right.cost?.currency.name ?? '';
    final byCostCurrency = leftCostCurrency.compareTo(rightCostCurrency);
    if (byCostCurrency != 0) {
      return byCostCurrency;
    }
    return left.units.number.compareTo(right.units.number);
  }
}
