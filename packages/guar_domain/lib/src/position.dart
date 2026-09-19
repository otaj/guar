// Units of a commodity held at an optional booked cost.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/cost.dart';

part 'position.freezed.dart';

@freezed
abstract class Position with _$Position {
  const factory Position({required Amount units, Cost? cost}) = _Position;
  const Position._();

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
    final int byCurrency = left.units.currency.name.compareTo(right.units.currency.name);
    if (byCurrency != 0) {
      return byCurrency;
    }
    final Decimal leftCost = left.cost?.number ?? Decimal.zero;
    final Decimal rightCost = right.cost?.number ?? Decimal.zero;
    final int byCost = leftCost.compareTo(rightCost);
    if (byCost != 0) {
      return byCost;
    }
    final String leftCostCurrency = left.cost?.currency.name ?? '';
    final String rightCostCurrency = right.cost?.currency.name ?? '';
    final int byCostCurrency = leftCostCurrency.compareTo(rightCostCurrency);
    if (byCostCurrency != 0) {
      return byCostCurrency;
    }
    return left.units.number.compareTo(right.units.number);
  }
}
