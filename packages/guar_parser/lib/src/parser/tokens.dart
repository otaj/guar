// Petitparser token and expression fragments shared by directive parsers.

import 'package:decimal/decimal.dart';
import 'package:guar_parser/src/domain/domain.dart';
import 'package:petitparser/petitparser.dart';
import 'package:rational/rational.dart';

Parser<String> whitespaceInline() => (char(' ') | char('\t')).cast<String>();

Parser<void> spaces() => whitespaceInline().star().map((_) {});

Parser<BeanDate> date() {
  final Parser<int> year = digit().times(4).flatten().map(int.parse);
  final Parser<int> month = digit().times(2).flatten().map(int.parse);
  final Parser<int> day = digit().times(2).flatten().map(int.parse);
  final ChoiceParser<dynamic> sep = char('-') | char('/');
  return (year & sep & month & sep & day)
      .where((List<dynamic> values) => isValidBeanDate(values[0] as int, values[2] as int, values[4] as int))
      .map((List<dynamic> values) => BeanDate(year: values[0] as int, month: values[2] as int, day: values[4] as int));
}

Parser<String> quotedString() =>
    (char('"') & pattern('^"').star().flatten() & char('"')).map((List<dynamic> values) => values[1] as String);

Parser<Account> account() {
  final Parser<String> segment = (uppercase() & (word() | char('-')).star()).flatten();
  return (segment & (char(':') & segment).plus())
      .flatten()
      .where(isValidAccountName)
      .map((String name) => Account(name: name));
}

Parser<Currency> currency() => (pattern('A-Z/') & pattern("A-Z0-9._'-").star())
    .flatten()
    .where(isValidCurrencyName)
    .map((String name) => Currency(name: name));

Parser<BeanNumber> numberLiteral() {
  final Parser<dynamic> sign = (char('+') | char('-')).optional();
  final Parser<List<dynamic>> intPart = digit().plus() & (char(',') & digit().times(3)).star();
  final Parser<List<dynamic>?> frac = (char('.') & digit().plus()).optional();
  return (sign & intPart & frac).flatten().map((String verbatim) {
    final String normalized = verbatim.replaceAll(',', '');
    return BeanNumber(verbatim: verbatim, resolved: Decimal.parse(normalized));
  });
}

Decimal _divide(Decimal left, Decimal right, int maxScale) {
  // Finite expansions keep exact decimals; repeating ones round to maxScale from the expression.
  final Rational quotient = left / right;
  if (_hasFiniteDecimalExpansion(quotient)) {
    return quotient.toDecimal();
  }
  final Decimal wide = quotient.toDecimal(scaleOnInfinitePrecision: maxScale + 16);
  return wide.round(scale: maxScale);
}

bool _hasFiniteDecimalExpansion(Rational value) {
  BigInt denominator = value.denominator.abs();
  while (denominator.isEven) {
    denominator >>= 1;
  }
  final BigInt five = BigInt.from(5);
  while (denominator % five == BigInt.zero) {
    denominator ~/= five;
  }
  return denominator == BigInt.one;
}

class _ExprNum {
  _ExprNum(this.value, this.maxScale);
  final Decimal value;
  final int maxScale;
}

Parser<_ExprNum> _unsignedExprNumber() {
  final Parser<List<dynamic>> intPart = digit().plus() & (char(',') & digit().times(3)).star();
  final Parser<List<dynamic>?> frac = (char('.') & digit().plus()).optional();
  return (intPart & frac).flatten().map((String verbatim) {
    final String cleaned = verbatim.replaceAll(',', '');
    final int scale = cleaned.contains('.') ? cleaned.length - cleaned.indexOf('.') - 1 : 0;
    return _ExprNum(Decimal.parse(cleaned), scale);
  });
}

Parser<_ExprNum> _numberExprValue() {
  final SettableParser<_ExprNum> factor = undefined<_ExprNum>();
  final SettableParser<_ExprNum> term = undefined<_ExprNum>();
  final SettableParser<_ExprNum> expr = undefined<_ExprNum>();

  factor.set(
    ((char('+') & spaces() & factor).map((List<dynamic> values) => values[2] as _ExprNum) |
            (char('-') & spaces() & factor).map((List<dynamic> values) {
              final _ExprNum inner = values[2] as _ExprNum;
              return _ExprNum(-inner.value, inner.maxScale);
            }) |
            (char('(') & spaces() & expr & spaces() & char(')')).map((List<dynamic> values) => values[2] as _ExprNum) |
            _unsignedExprNumber())
        .cast<_ExprNum>(),
  );

  term.set(
    (factor & (spaces() & (char('*') | char('/')) & spaces() & factor).star()).map((List<dynamic> values) {
      _ExprNum result = values[0] as _ExprNum;
      for (final dynamic part in values[1] as List<dynamic>) {
        final List<dynamic> items = part as List<dynamic>;
        final String op = items[1] as String;
        final _ExprNum right = items[3] as _ExprNum;
        final int scale = result.maxScale > right.maxScale ? result.maxScale : right.maxScale;
        result = op == '*'
            ? _ExprNum(result.value * right.value, scale)
            : _ExprNum(_divide(result.value, right.value, scale), scale);
      }
      return result;
    }),
  );

  expr.set(
    (term & (spaces() & (char('+') | char('-')) & spaces() & term).star()).map((List<dynamic> values) {
      _ExprNum result = values[0] as _ExprNum;
      for (final dynamic part in values[1] as List<dynamic>) {
        final List<dynamic> items = part as List<dynamic>;
        final String op = items[1] as String;
        final _ExprNum right = items[3] as _ExprNum;
        final int scale = result.maxScale > right.maxScale ? result.maxScale : right.maxScale;
        result = _ExprNum(op == '+' ? result.value + right.value : result.value - right.value, scale);
      }
      return result;
    }),
  );

  return expr;
}

final Parser<BeanNumber> _numberExpr = _numberExprValue().token().map(
  (Token<_ExprNum> token) =>
      BeanNumber(verbatim: token.buffer.substring(token.start, token.stop), resolved: token.value.value),
);

Parser<BeanNumber> numberExpr() => _numberExpr;

Parser<Amount> amount() => (numberExpr() & spaces() & currency()).map(
  (List<dynamic> values) => Amount(number: values[0] as BeanNumber, currency: values[2] as Currency),
);

Parser<Flag> flag() {
  final Parser<Flag> txn = string('txn').map((_) => const Flag.special(SpecialFlag.asterisk));
  final Parser<Flag> special = pattern('*!&#?%').map(
    (String lexeme) => Flag.special(switch (lexeme) {
      '*' => SpecialFlag.asterisk,
      '!' => SpecialFlag.exclamation,
      '#' => SpecialFlag.hash,
      '&' => SpecialFlag.ampersand,
      '?' => SpecialFlag.question,
      '%' => SpecialFlag.percent,
      _ => SpecialFlag.asterisk,
    }),
  );
  final Parser<Flag> letter = pattern('A-Z').map(Flag.letter);
  return (txn | special | letter).cast<Flag>();
}

Parser<IncompleteAmount> incompleteAmount({bool allowEmpty = false}) {
  final Parser<IncompleteAmount> both = (numberExpr() & spaces() & currency()).map(
    (List<dynamic> values) => IncompleteAmount(number: values[0] as BeanNumber, currency: values[2] as Currency),
  );
  final Parser<IncompleteAmount> numberOnly = numberExpr().map((BeanNumber number) => IncompleteAmount(number: number));
  final Parser<IncompleteAmount> currencyOnly = currency().map(
    (Currency currency) => IncompleteAmount(currency: currency),
  );
  if (allowEmpty) {
    return (both | numberOnly | currencyOnly | epsilon().map((_) => const IncompleteAmount())).cast();
  }
  return (both | numberOnly | currencyOnly).cast();
}

Parser<IncompleteAmount?> units() => incompleteAmount().optional();

Parser<ParsedPrice> priceSpec() {
  final Parser<ParsedPrice> total = (string('@@') & spaces() & incompleteAmount(allowEmpty: true)).map((
    List<dynamic> values,
  ) {
    final IncompleteAmount amount = values[2] as IncompleteAmount;
    return ParsedPrice(number: amount.number, currency: amount.currency, isTotal: true);
  });
  final Parser<ParsedPrice> perUnit = (char('@') & spaces() & incompleteAmount(allowEmpty: true)).map((
    List<dynamic> values,
  ) {
    final IncompleteAmount amount = values[2] as IncompleteAmount;
    return ParsedPrice(number: amount.number, currency: amount.currency);
  });
  return (total | perUnit).cast();
}

Parser<MetaEntry> metaEntry() {
  final Parser<String> key = (pattern('a-z') & pattern('A-Za-z0-9_-').star()).flatten();
  final Parser<String> tagName = pattern('A-Za-z0-9_./-').plus().flatten();
  final Parser<MetaValue> boolValue = (string('TRUE') | string('FALSE')).map(
    (dynamic lexeme) => MetaValue.boolean(lexeme == 'TRUE'),
  );
  final Parser<MetaValue> textValue = quotedString().map(MetaValue.text);
  final Parser<MetaValue> dateValue = date().map(MetaValue.date);
  final Parser<MetaValue> accountValue = account().map(MetaValue.account);
  final Parser<MetaValue> tagValue = (char('#') & tagName).map(
    (List<dynamic> values) => MetaValue.tag(Tag(name: values[1] as String)),
  );
  final Parser<MetaValue> amountValue = (numberExpr() & spaces() & currency()).map(
    (List<dynamic> values) =>
        MetaValue.amount(Amount(number: values[0] as BeanNumber, currency: values[2] as Currency)),
  );
  final Parser<MetaValue> numberValue = numberExpr().map(MetaValue.number);
  final Parser<MetaValue> currencyValue = currency().map(MetaValue.currency);
  final Parser<MetaValue> value =
      (textValue | boolValue | dateValue | accountValue | tagValue | amountValue | numberValue | currencyValue)
          .cast<MetaValue>();
  return (key & spaces() & char(':') & spaces() & value.optional()).map(
    (List<dynamic> values) => MetaEntry(key: values[0] as String, value: values[4] as MetaValue?),
  );
}

Parser<ParsedCost> costSpec() {
  // Fresh per call so gated components reject a second amount/date/label/merge.
  final Set<String> seen = <String>{};

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
  ) => (epsilon().where((_) => !seen.contains(kind)) & inner).map((List<dynamic> values) {
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

  final Parser<
    ({
      Currency? currency,
      BeanDate? date,
      String? label,
      bool merge,
      bool nonempty,
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
    })
  >
  compound =
      (numberExpr().optional() &
              (spaces() & char('#') & spaces() & numberExpr().optional()).optional() &
              (spaces() & currency()).optional())
          .map((List<dynamic> values) {
            final BeanNumber? per = values[0] as BeanNumber?;
            final List<dynamic>? hashPart = values[1] as List<dynamic>?;
            final BeanNumber? total = hashPart == null ? null : hashPart[3] as BeanNumber?;
            final List<dynamic>? currencyPart = values[2] as List<dynamic>?;
            final Currency? currency = currencyPart == null ? null : currencyPart[1] as Currency;
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
          .where(
            (
              ({
                Currency? currency,
                BeanDate? date,
                String? label,
                bool merge,
                bool nonempty,
                BeanNumber? numberPer,
                BeanNumber? numberTotal,
              })
              value,
            ) => value.nonempty,
          );
  final Parser<
    ({
      Currency? currency,
      BeanDate date,
      String? label,
      bool merge,
      bool nonempty,
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
    })
  >
  dateComp = date().map(
    (BeanDate d) => (
      numberPer: null as BeanNumber?,
      numberTotal: null as BeanNumber?,
      currency: null as Currency?,
      date: d,
      label: null as String?,
      merge: false,
      nonempty: true,
    ),
  );
  final Parser<
    ({
      Currency? currency,
      BeanDate? date,
      String label,
      bool merge,
      bool nonempty,
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
    })
  >
  labelComp = quotedString().map(
    (String s) => (
      numberPer: null as BeanNumber?,
      numberTotal: null as BeanNumber?,
      currency: null as Currency?,
      date: null as BeanDate?,
      label: s,
      merge: false,
      nonempty: true,
    ),
  );
  final Parser<
    ({
      Currency? currency,
      BeanDate? date,
      String? label,
      bool merge,
      bool nonempty,
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
    })
  >
  mergeComp = char('*').map(
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
  final Parser<
    ({
      Currency? currency,
      BeanDate? date,
      String? label,
      bool merge,
      bool nonempty,
      BeanNumber? numberPer,
      BeanNumber? numberTotal,
    })
  >
  component = (once('date', dateComp) | once('label', labelComp) | once('merge', mergeComp) | once('amount', compound))
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
  final Parser<List<dynamic>?> list =
      (spaces() & component & (spaces() & char(',') & spaces() & component).star() & spaces()).optional();
  ParsedCost fromBody(dynamic raw, {required bool total}) {
    BeanNumber? numberPer;
    BeanNumber? numberTotal;
    Currency? currency;
    BeanDate? date;
    String? label;
    bool merge = false;
    final List<dynamic>? body = raw as List<dynamic>?;
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
      for (final dynamic part in body[2] as List<dynamic>) {
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
    if (total && numberTotal == null && numberPer != null) {
      numberTotal = numberPer;
      numberPer = null;
    }
    return ParsedCost(
      numberPer: numberPer,
      numberTotal: numberTotal,
      currency: currency,
      date: date,
      label: label,
      merge: merge,
    );
  }

  final Parser<ParsedCost> total = (string('{{') & list & string('}}')).map(
    (List<dynamic> values) => fromBody(values[1], total: true),
  );
  final Parser<ParsedCost> unit = (char('{') & list & char('}')).map(
    (List<dynamic> values) => fromBody(values[1], total: false),
  );
  return (total | unit).cast();
}
