// Complete amount: a computed decimal with its commodity.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';

part 'amount.freezed.dart';

@freezed
abstract class Amount with _$Amount {
  const Amount._();

  const factory Amount({required Decimal number, required Currency currency, @Default(0) int scale}) = _Amount;

  @override
  String toString() => '$number ${currency.name}';

  Amount operator -() => Amount(number: -number, currency: currency, scale: scale);

  static Amount mul(Amount amount, Decimal scalar) =>
      Amount(number: amount.number * scalar, currency: amount.currency, scale: amount.scale);

  static Amount div(Amount amount, Decimal scalar) =>
      Amount(number: (amount.number / scalar).toDecimal(), currency: amount.currency, scale: amount.scale);

  static Amount add(Amount left, Amount right) {
    if (left.currency != right.currency) {
      throw ArgumentError('Unmatching currencies for operation on $left and $right');
    }
    return Amount(
      number: left.number + right.number,
      currency: left.currency,
      scale: left.scale > right.scale ? left.scale : right.scale,
    );
  }

  static Amount sub(Amount left, Amount right) {
    if (left.currency != right.currency) {
      throw ArgumentError('Unmatching currencies for operation on $left and $right');
    }
    return Amount(
      number: left.number - right.number,
      currency: left.currency,
      scale: left.scale > right.scale ? left.scale : right.scale,
    );
  }

  static Amount abs(Amount amount) => amount.number >= Decimal.zero
      ? amount
      : Amount(number: -amount.number, currency: amount.currency, scale: amount.scale);

  static int compare(Amount left, Amount right) {
    final byCurrency = left.currency.name.compareTo(right.currency.name);
    if (byCurrency != 0) {
      return byCurrency;
    }
    return left.number.compareTo(right.number);
  }
}
