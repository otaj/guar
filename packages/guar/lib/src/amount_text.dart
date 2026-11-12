// Renders amounts with the digits the ledger parsed, e.g. 1.10 not Decimal's 1.1.

import 'package:guar_domain/guar_domain.dart';

String amountText(Amount amount) {
  final String number = '${amount.number}';
  final int digits = number.contains('.') ? number.length - number.indexOf('.') - 1 : 0;
  if (amount.scale <= digits) return '$number ${amount.currency.name}';
  final String base = number.contains('.') ? number : '$number.';
  return '$base${'0' * (amount.scale - digits)} ${amount.currency.name}';
}
