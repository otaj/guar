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
  return (year & sep & month & sep & day)
      .map((values) {
        return BeanDate(year: values[0] as int, month: values[2] as int, day: values[4] as int);
      })
      .where((date) => date.month >= 1 && date.month <= 12 && date.day >= 1 && date.day <= 31);
}

Parser<String> quotedString() {
  return (char('"') & pattern('^"').star().flatten() & char('"')).map((values) => values[1] as String);
}

Parser<Account> account() {
  final segment = (uppercase() & (word() | char('-')).star()).flatten();
  return (segment & (char(':') & segment).plus()).flatten().map((name) => Account(name: name));
}

Parser<Currency> currency() {
  return (pattern(r'A-Z/') & pattern(r"A-Z0-9._'-").star()).flatten().map((name) => Currency(name: name));
}

Parser<BeanNumber> numberLiteral() {
  final sign = (char('+') | char('-')).optional();
  final intPart = digit().plus() & (char(',') & digit().times(3)).star();
  final frac = (char('.') & digit().plus()).optional();
  return (sign & intPart & frac).flatten().map((verbatim) {
    final normalized = verbatim.replaceAll(',', '');
    return BeanNumber(verbatim: verbatim, resolved: Decimal.parse(normalized));
  });
}

Parser<Decimal> _unsignedNumber() {
  final intPart = digit().plus() & (char(',') & digit().times(3)).star();
  final frac = (char('.') & digit().plus()).optional();
  return (intPart & frac).flatten().map((verbatim) => Decimal.parse(verbatim.replaceAll(',', '')));
}

Decimal _divide(Decimal left, Decimal right) {
  return (left / right).toDecimal(scaleOnInfinitePrecision: 28);
}

Parser<Decimal> _numberExprValue() {
  final factor = undefined<Decimal>();
  final term = undefined<Decimal>();
  final expr = undefined<Decimal>();

  factor.set(
    ((char('+') & spaces() & factor).map((values) => values[2] as Decimal) |
            (char('-') & spaces() & factor).map((values) => -(values[2] as Decimal)) |
            (char('(') & spaces() & expr & spaces() & char(')')).map((values) => values[2] as Decimal) |
            _unsignedNumber())
        .cast<Decimal>(),
  );

  term.set(
    (factor & (spaces() & (char('*') | char('/')) & spaces() & factor).star()).map((values) {
      var result = values[0] as Decimal;
      for (final part in values[1] as List<dynamic>) {
        final items = part as List<dynamic>;
        final op = items[1] as String;
        final right = items[3] as Decimal;
        result = op == '*' ? result * right : _divide(result, right);
      }
      return result;
    }),
  );

  expr.set(
    (term & (spaces() & (char('+') | char('-')) & spaces() & term).star()).map((values) {
      var result = values[0] as Decimal;
      for (final part in values[1] as List<dynamic>) {
        final items = part as List<dynamic>;
        final op = items[1] as String;
        final right = items[3] as Decimal;
        result = op == '+' ? result + right : result - right;
      }
      return result;
    }),
  );

  return expr;
}

final Parser<BeanNumber> _numberExpr = _numberExprValue().token().map((token) {
  return BeanNumber(verbatim: token.buffer.substring(token.start, token.stop), resolved: token.value);
});

Parser<BeanNumber> numberExpr() => _numberExpr;

Parser<Amount> amount() {
  return (numberExpr() & spaces() & currency()).map((values) {
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

Parser<IncompleteAmount> incompleteAmount({bool allowEmpty = false}) {
  final both = (numberExpr() & spaces() & currency()).map((values) {
    return IncompleteAmount(number: values[0] as BeanNumber, currency: values[2] as Currency);
  });
  final numberOnly = numberExpr().map((number) => IncompleteAmount(number: number));
  final currencyOnly = currency().map((currency) => IncompleteAmount(currency: currency));
  if (allowEmpty) {
    return (both | numberOnly | currencyOnly | epsilon().map((_) => const IncompleteAmount())).cast();
  }
  return (both | numberOnly | currencyOnly).cast();
}

Parser<IncompleteAmount?> units() => incompleteAmount().optional();

Parser<ParsedPrice> priceSpec() {
  final total = (string('@@') & spaces() & incompleteAmount(allowEmpty: true)).map((values) {
    final amount = values[2] as IncompleteAmount;
    return ParsedPrice(number: amount.number, currency: amount.currency, isTotal: true);
  });
  final perUnit = (char('@') & spaces() & incompleteAmount(allowEmpty: true)).map((values) {
    final amount = values[2] as IncompleteAmount;
    return ParsedPrice(number: amount.number, currency: amount.currency);
  });
  return (total | perUnit).cast();
}

Parser<MetaEntry> metaEntry() {
  final key = (pattern('a-z') & pattern(r'A-Za-z0-9_-').star()).flatten();
  final tagName = pattern(r'A-Za-z0-9_./-').plus().flatten();
  final boolValue = (string('TRUE') | string('FALSE')).map((lexeme) => MetaValue.boolean(lexeme == 'TRUE'));
  final textValue = quotedString().map(MetaValue.text);
  final dateValue = date().map(MetaValue.date);
  final accountValue = account().map(MetaValue.account);
  final tagValue = (char('#') & tagName).map((values) => MetaValue.tag(Tag(name: values[1] as String)));
  final amountValue = (numberExpr() & spaces() & currency()).map(
    (values) => MetaValue.amount(Amount(number: values[0] as BeanNumber, currency: values[2] as Currency)),
  );
  final numberValue = numberExpr().map(MetaValue.number);
  final currencyValue = currency().map(MetaValue.currency);
  final value =
      (textValue | boolValue | dateValue | accountValue | tagValue | amountValue | numberValue | currencyValue)
          .cast<MetaValue>();
  return (key & spaces() & char(':') & spaces() & value.optional()).map((values) {
    return MetaEntry(key: values[0] as String, value: values[4] as MetaValue?);
  });
}

Parser<ParsedCost> costSpec() {
  // Fresh per call so gated components reject a second amount/date/label/merge.
  final seen = <String>{};

  Parser<
    ({
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
      Currency? currency,
      BeanDate? date,
      String? label,
      bool merge,
      bool nonempty,
    })
  >
  once(
    String kind,
    Parser<
      ({
        BeanNumber? numberPer,
        BeanNumber? numberTotal,
        Currency? currency,
        BeanDate? date,
        String? label,
        bool merge,
        bool nonempty,
      })
    >
    inner,
  ) {
    return (epsilon().where((_) => !seen.contains(kind)) & inner).map((values) {
      seen.add(kind);
      return values[1]
          as ({
            BeanNumber? numberPer,
            BeanNumber? numberTotal,
            Currency? currency,
            BeanDate? date,
            String? label,
            bool merge,
            bool nonempty,
          });
    });
  }

  final compound =
      (numberExpr().optional() &
              (spaces() & char('#') & spaces() & numberExpr().optional()).optional() &
              (spaces() & currency()).optional())
          .map((values) {
            final per = values[0] as BeanNumber?;
            final hashPart = values[1] as List<dynamic>?;
            final total = hashPart == null ? null : hashPart[3] as BeanNumber?;
            final currencyPart = values[2] as List<dynamic>?;
            final currency = currencyPart == null ? null : currencyPart[1] as Currency;
            return (
              numberPer: per,
              numberTotal: total,
              currency: currency,
              date: null as BeanDate?,
              label: null as String?,
              merge: false,
              nonempty: per != null || hashPart != null || currency != null,
            );
          })
          .where((value) => value.nonempty);
  final dateComp = date().map(
    (d) => (
      numberPer: null as BeanNumber?,
      numberTotal: null as BeanNumber?,
      currency: null as Currency?,
      date: d,
      label: null as String?,
      merge: false,
      nonempty: true,
    ),
  );
  final labelComp = quotedString().map(
    (s) => (
      numberPer: null as BeanNumber?,
      numberTotal: null as BeanNumber?,
      currency: null as Currency?,
      date: null as BeanDate?,
      label: s,
      merge: false,
      nonempty: true,
    ),
  );
  final mergeComp = char('*').map(
    (_) => (
      numberPer: null as BeanNumber?,
      numberTotal: null as BeanNumber?,
      currency: null as Currency?,
      date: null as BeanDate?,
      label: null as String?,
      merge: true,
      nonempty: true,
    ),
  );
  final component =
      (once('date', dateComp) | once('label', labelComp) | once('merge', mergeComp) | once('amount', compound))
          .cast<
            ({
              BeanNumber? numberPer,
              BeanNumber? numberTotal,
              Currency? currency,
              BeanDate? date,
              String? label,
              bool merge,
              bool nonempty,
            })
          >();
  final list = (spaces() & component & (spaces() & char(',') & spaces() & component).star() & spaces()).optional();
  return (char('{') & list & char('}')).map((values) {
    BeanNumber? numberPer;
    BeanNumber? numberTotal;
    Currency? currency;
    BeanDate? date;
    String? label;
    var merge = false;
    final body = values[1] as List<dynamic>?;
    if (body != null) {
      void take(
        ({
          BeanNumber? numberPer,
          BeanNumber? numberTotal,
          Currency? currency,
          BeanDate? date,
          String? label,
          bool merge,
          bool nonempty,
        })
        c,
      ) {
        numberPer ??= c.numberPer;
        numberTotal ??= c.numberTotal;
        currency ??= c.currency;
        date ??= c.date;
        label ??= c.label;
        merge = merge || c.merge;
      }

      take(
        body[1]
            as ({
              BeanNumber? numberPer,
              BeanNumber? numberTotal,
              Currency? currency,
              BeanDate? date,
              String? label,
              bool merge,
              bool nonempty,
            }),
      );
      for (final part in body[2] as List<dynamic>) {
        take(
          (part as List<dynamic>)[3]
              as ({
                BeanNumber? numberPer,
                BeanNumber? numberTotal,
                Currency? currency,
                BeanDate? date,
                String? label,
                bool merge,
                bool nonempty,
              }),
        );
      }
    }
    return ParsedCost(
      numberPer: numberPer,
      numberTotal: numberTotal,
      currency: currency,
      date: date,
      label: label,
      merge: merge,
    );
  });
}
