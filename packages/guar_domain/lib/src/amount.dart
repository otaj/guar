// Complete amount: a computed decimal with its commodity.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';

part 'amount.freezed.dart';

@freezed
abstract class Amount with _$Amount {
  const Amount._();

  const factory Amount({required Decimal number, required Currency currency}) = _Amount;

  @override
  String toString() => '$number ${currency.name}';

  Amount operator -() => Amount(number: -number, currency: currency);

  static Amount mul(Amount amount, Decimal scalar) => Amount(number: amount.number * scalar, currency: amount.currency);

  static Amount div(Amount amount, Decimal scalar) =>
      Amount(number: (amount.number / scalar).toDecimal(), currency: amount.currency);

  static Amount add(Amount left, Amount right) {
    if (left.currency != right.currency) {
      throw ArgumentError('Unmatching currencies for operation on $left and $right');
    }
    return Amount(number: left.number + right.number, currency: left.currency);
  }

  static Amount sub(Amount left, Amount right) {
    if (left.currency != right.currency) {
      throw ArgumentError('Unmatching currencies for operation on $left and $right');
    }
    return Amount(number: left.number - right.number, currency: left.currency);
  }

  static Amount abs(Amount amount) =>
      amount.number >= Decimal.zero ? amount : Amount(number: -amount.number, currency: amount.currency);

  static int compare(Amount left, Amount right) {
    final byCurrency = left.currency.name.compareTo(right.currency.name);
    if (byCurrency != 0) {
      return byCurrency;
    }
    return left.number.compareTo(right.number);
  }
}
