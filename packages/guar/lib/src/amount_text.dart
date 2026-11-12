// Renders amounts with the digits the ledger parsed, e.g. 1.10 not Decimal's 1.1.

import 'package:guar_domain/guar_domain.dart';

String amountText(Amount amount) {
  final String number = amount.number.toString();
  final int digits = number.contains('.') ? number.length - number.indexOf('.') - 1 : 0;
  final String padded = amount.scale > digits ? '$number${'0' * (amount.scale - digits)}' : number;
  return '$padded ${amount.currency.name}';
}
