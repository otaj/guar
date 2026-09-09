// Petitparser token and expression fragments shared by directive parsers.

import 'package:decimal/decimal.dart';
import 'package:petitparser/petitparser.dart';

import '../domain/domain.dart';

Parser<String> whitespaceInline() => (char(' ') | char('\t')).cast<String>();

Parser<void> spaces() => whitespaceInline().star().map((_) {});

Parser<BeanDate> date() {
  final year = digit().times(4).flatten().map(int.parse);
  final month = digit().times(2).flatten().map(int.parse);
  final day = digit().times(2).flatten().map(int.parse);
  final sep = char('-') | char('/');
  return (year & sep & month & sep & day).map((values) {
    return BeanDate(year: values[0] as int, month: values[2] as int, day: values[4] as int);
  });
}

Parser<String> quotedString() {
  return (char('"') & pattern('^"').star().flatten() & char('"')).map((values) => values[1] as String);
}

Parser<Account> account() {
  final segment = (uppercase() & (word() | char('-')).star()).flatten();
  return (segment & (char(':') & segment).plus()).flatten().map((name) => Account(name: name));
}

Parser<Currency> currency() {
  return (pattern('A-Z') & pattern(r'A-Z0-9._-').star()).flatten().map((name) => Currency(name: name));
}

Parser<BeanNumber> numberLiteral() {
  final sign = (char('+') | char('-')).optional();
  final intPart = digit().plus();
  final frac = (char('.') & digit().plus()).optional();
  return (sign & intPart & frac).flatten().map((verbatim) {
    final normalized = verbatim.replaceAll(',', '');
    return BeanNumber(verbatim: verbatim, resolved: Decimal.parse(normalized));
  });
}

Parser<Amount> amount() {
  return (numberLiteral() & spaces() & currency()).map((values) {
    return Amount(number: values[0] as BeanNumber, currency: values[2] as Currency);
  });
}

Parser<Flag> flag() {
  final txn = string('txn').map((_) => const Flag.special(SpecialFlag.asterisk));
  final special = pattern(r'*!&#?%').map((lexeme) {
    return Flag.special(switch (lexeme) {
      '*' => SpecialFlag.asterisk,
      '!' => SpecialFlag.exclamation,
      '#' => SpecialFlag.hash,
      '&' => SpecialFlag.ampersand,
      '?' => SpecialFlag.question,
      '%' => SpecialFlag.percent,
      _ => SpecialFlag.asterisk,
    });
  });
  final letter = pattern('A-Z').map((lexeme) => Flag.letter(lexeme));
  return (txn | special | letter).cast<Flag>();
}

Parser<IncompleteAmount?> units() {
  final amount = (numberLiteral() & spaces() & currency()).map((values) {
    return IncompleteAmount(number: values[0] as BeanNumber, currency: values[2] as Currency);
  });
  return amount.optional();
}
