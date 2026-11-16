// Quantization of interpolated fills to the tolerance grid.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/booking/interpolate.dart';
import 'package:test/test.dart';

void main() {
  InferredTolerances tolerances(String currency, String value) =>
      InferredTolerances(<String, Decimal>{currency: Decimal.parse(value)});

  test('snaps a near miss onto the tolerance grid', () {
    final Decimal result = quantizeWithTolerance(tolerances('USD', '0.005'), 'USD', Decimal.parse('100.0005'));
    expect(result, Decimal.parse('100.00'));
  });

  test('zero tolerance leaves the number alone', () {
    final Decimal result = quantizeWithTolerance(tolerances('USD', '0'), 'USD', Decimal.parse('100.0005'));
    expect(result, Decimal.parse('100.0005'));
  });

  test('a tolerance too fine for five coefficient digits is ignored', () {
    final Decimal result = quantizeWithTolerance(tolerances('USD', '0.000001'), 'USD', Decimal.parse('100.0005'));
    expect(result, Decimal.parse('100.0005'));
  });

  test('an unknown currency falls back to zero tolerance', () {
    final Decimal result = quantizeWithTolerance(tolerances('EUR', '0.005'), 'USD', Decimal.parse('100.0005'));
    expect(result, Decimal.parse('100.0005'));
  });
}
