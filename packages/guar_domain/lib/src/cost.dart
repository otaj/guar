// Booked per-unit acquisition cost of a lot.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'date.dart';

part 'cost.freezed.dart';

@freezed
abstract class Cost with _$Cost {
  const Cost._();

  const factory Cost({required Decimal number, required Currency currency, required BeanDate date, String? label}) =
      _Cost;

  @override
  String toString({bool detail = true}) {
    final parts = <String>['$number ${currency.name}'];
    if (detail) {
      parts.add('$date');
      if (label != null) {
        parts.add('"$label"');
      }
    }
    return parts.join(', ');
  }
}
