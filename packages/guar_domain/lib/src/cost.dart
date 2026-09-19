// Booked per-unit acquisition cost of a lot.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/date.dart';

part 'cost.freezed.dart';

@freezed
abstract class Cost with _$Cost {
  const factory Cost({required Decimal number, required Currency currency, required BeanDate date, String? label}) =
      _Cost;
  const Cost._();

  @override
  String toString({bool detail = true}) {
    final List<String> parts = <String>['$number ${currency.name}'];
    if (detail) {
      parts.add('$date');
      if (label != null) {
        parts.add('"$label"');
      }
    }
    return parts.join(', ');
  }
}
