// Number as written in the ledger and its evaluated decimal form.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'number.freezed.dart';

@freezed
abstract class BeanNumber with _$BeanNumber {
  const factory BeanNumber({required String verbatim, required Decimal resolved}) = _BeanNumber;
}

extension BeanNumberPlaces on BeanNumber {
  // Digits written after the dot; expressions fall back to the resolved value's digits.
  int get places {
    final String compact = verbatim.replaceAll(',', '').replaceAll(' ', '');
    final RegExpMatch? match = RegExp(r'^[+-]?\d+(?:\.(\d+))?$').firstMatch(compact);
    if (match != null) {
      return match.group(1)?.length ?? 0;
    }
    final String resolvedText = resolved.toString();
    final int dot = resolvedText.indexOf('.');
    return dot < 0 ? 0 : resolvedText.length - dot - 1;
  }
}
