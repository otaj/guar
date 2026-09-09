// Number as written in the ledger and its evaluated decimal form.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'number.freezed.dart';

@freezed
abstract class BeanNumber with _$BeanNumber {
  const factory BeanNumber({required String verbatim, required Decimal resolved}) = _BeanNumber;
}
