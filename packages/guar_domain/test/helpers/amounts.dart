// Shared constructors for booked-domain unit tests.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

Amount amount(String number, String currency) => Amount(
  number: Decimal.parse(number),
  currency: Currency(name: currency),
);

Position position(String number, String currency, {Cost? cost}) =>
    Position(units: amount(number, currency), cost: cost);

Cost cost(String number, String currency, BeanDate date, {String? label}) => Cost(
  number: Decimal.parse(number),
  currency: Currency(name: currency),
  date: date,
  label: label,
);

Account account(String name, AccountType type) => Account(name: name, type: type);
