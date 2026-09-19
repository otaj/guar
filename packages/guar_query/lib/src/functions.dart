// Function and operator evaluation for compiled BQL expressions.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_query/src/convert.dart';
import 'package:guar_query/src/helpers.dart';
import 'package:guar_query/src/tables.dart';
import 'package:guar_query/src/value.dart';

typedef EvalFn = QueryValue Function(Object row, TableEnv env, List<QueryValue> args);

class FuncSpec {
  FuncSpec(this.name, this.argTypes, this.outType, this.eval, {this.aggregate = false, this.passContext = false});
  final String name;
  final List<QueryType> argTypes;
  final QueryType outType;
  final EvalFn eval;
  final bool aggregate;
  final bool passContext;
}

bool typeMatches(QueryType expected, QueryType actual) {
  if (expected == QueryType.object || actual == QueryType.object) return true;
  if (expected == actual) return true;
  if (expected == QueryType.text &&
      (actual == QueryType.account || actual == QueryType.currency || actual == QueryType.flag)) {
    return true;
  }
  if (expected == QueryType.set &&
      (actual == QueryType.tags ||
          actual == QueryType.links ||
          actual == QueryType.accounts ||
          actual == QueryType.set)) {
    return true;
  }
  if (expected == QueryType.asterisk && actual == QueryType.asterisk) return true;
  return false;
}

List<FuncSpec> builtinFunctions() => <FuncSpec>[
  FuncSpec('bool', <QueryType>[QueryType.object], QueryType.boolean, (Object row, TableEnv env, List<QueryValue> args) {
    if (args.single.isNull) return const QueryValue.null_();
    return QueryValue.boolean(isTruthy(args.single));
  }),
  FuncSpec(
    'int',
    <QueryType>[QueryType.object],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => _toInt(args.single),
  ),
  FuncSpec(
    'decimal',
    <QueryType>[QueryType.object],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) => _toDecimal(args.single),
  ),
  FuncSpec(
    'str',
    <QueryType>[QueryType.object],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text(_stringify(args.single)),
  ),
  FuncSpec(
    'date',
    <QueryType>[QueryType.object],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) => _toDate(args.single),
  ),
  FuncSpec('date', <QueryType>[QueryType.integer, QueryType.integer, QueryType.integer], QueryType.date, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    try {
      return QueryValue.date(
        BeanDate(
          year: (args[0] as QueryInteger).value,
          month: (args[1] as QueryInteger).value,
          day: (args[2] as QueryInteger).value,
        ),
      );
    } on Object {
      return const QueryValue.null_();
    }
  }),
  FuncSpec(
    'neg',
    <QueryType>[QueryType.integer],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer(-(args.single as QueryInteger).value),
  ),
  FuncSpec(
    'neg',
    <QueryType>[QueryType.number],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.number(-(args.single as QueryNumber).value),
  ),
  FuncSpec(
    'neg',
    <QueryType>[QueryType.amount],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.amount(-(args.single as QueryAmount).value),
  ),
  FuncSpec(
    'neg',
    <QueryType>[QueryType.position],
    QueryType.position,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.position(-(args.single as QueryPosition).value),
  ),
  FuncSpec(
    'neg',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.inventory(-(args.single as QueryInventory).value),
  ),
  FuncSpec('abs', <QueryType>[QueryType.number], QueryType.number, (Object row, TableEnv env, List<QueryValue> args) {
    final Decimal number = (args.single as QueryNumber).value;
    return QueryValue.number(number < Decimal.zero ? -number : number);
  }),
  FuncSpec(
    'abs',
    <QueryType>[QueryType.position],
    QueryType.position,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.position((args.single as QueryPosition).value.absolute),
  ),
  FuncSpec(
    'abs',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.inventory((args.single as QueryInventory).value.absolute),
  ),
  FuncSpec(
    'round',
    <QueryType>[QueryType.number],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.number((args.single as QueryNumber).value.round()),
  ),
  FuncSpec(
    'round',
    <QueryType>[QueryType.number, QueryType.integer],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.number((args[0] as QueryNumber).value.round(scale: (args[1] as QueryInteger).value)),
  ),
  FuncSpec(
    'length',
    <QueryType>[QueryType.text],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer((args.single.asText() ?? '').length),
  ),
  FuncSpec(
    'length',
    <QueryType>[QueryType.set],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer(_setLength(args.single)),
  ),
  FuncSpec(
    'year',
    <QueryType>[QueryType.date],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer((args.single as QueryDate).value.year),
  ),
  FuncSpec(
    'month',
    <QueryType>[QueryType.date],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer((args.single as QueryDate).value.month),
  ),
  FuncSpec(
    'day',
    <QueryType>[QueryType.date],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.integer((args.single as QueryDate).value.day),
  ),
  FuncSpec('yearmonth', <QueryType>[QueryType.date], QueryType.date, (Object row, TableEnv env, List<QueryValue> args) {
    final BeanDate date = (args.single as QueryDate).value;
    return QueryValue.date(BeanDate(year: date.year, month: date.month, day: 1));
  }),
  FuncSpec('quarter', <QueryType>[QueryType.date], QueryType.text, (Object row, TableEnv env, List<QueryValue> args) {
    final BeanDate date = (args.single as QueryDate).value;
    return QueryValue.text('${date.year.toString().padLeft(4, '0')}-Q${(date.month - 1) ~/ 3 + 1}');
  }),
  FuncSpec('weekday', <QueryType>[QueryType.date], QueryType.text, (Object row, TableEnv env, List<QueryValue> args) {
    final BeanDate date = (args.single as QueryDate).value;
    return QueryValue.text(
      <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.utc(date.year, date.month, date.day).weekday -
          1],
    );
  }),
  FuncSpec('today', <QueryType>[], QueryType.date, (Object row, TableEnv env, List<QueryValue> args) {
    final DateTime now = env.clock();
    return QueryValue.date(BeanDate(year: now.year, month: now.month, day: now.day));
  }),
  FuncSpec(
    'root',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text(rootAccount(args.single.asText() ?? '', 1)),
  ),
  FuncSpec(
    'root',
    <QueryType>[QueryType.text, QueryType.integer],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.text(rootAccount(args[0].asText() ?? '', (args[1] as QueryInteger).value)),
  ),
  FuncSpec(
    'parent',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text(parentAccount(args.single.asText() ?? '')),
  ),
  FuncSpec(
    'leaf',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text(leafAccount(args.single.asText() ?? '')),
  ),
  FuncSpec(
    'upper',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text((args.single.asText() ?? '').toUpperCase()),
  ),
  FuncSpec(
    'lower',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text((args.single.asText() ?? '').toLowerCase()),
  ),
  FuncSpec('substr', <QueryType>[QueryType.text, QueryType.integer, QueryType.integer], QueryType.text, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final String text = args[0].asText() ?? '';
    final int start = (args[1] as QueryInteger).value;
    final int end = (args[2] as QueryInteger).value;
    final int from = start < 0 ? 0 : start;
    final int to = end > text.length ? text.length : end;
    if (from >= to) return const QueryValue.text('');
    return QueryValue.text(text.substring(from, to));
  }),
  FuncSpec(
    'units',
    <QueryType>[QueryType.position],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.amount(unitsOf((args.single as QueryPosition).value)),
  ),
  FuncSpec(
    'units',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.inventory(reduceUnits((args.single as QueryInventory).value)),
  ),
  FuncSpec(
    'cost',
    <QueryType>[QueryType.position],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.amount(costOf((args.single as QueryPosition).value)),
  ),
  FuncSpec(
    'cost',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.inventory(reduceCost((args.single as QueryInventory).value)),
  ),
  FuncSpec('weight', <QueryType>[QueryType.position], QueryType.amount, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    if (row is PostingRow) return QueryValue.amount(weightOf(row.posting));
    return QueryValue.amount(costOf((args.single as QueryPosition).value));
  }),
  FuncSpec('value', <QueryType>[QueryType.position], QueryType.amount, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Amount? value = marketValue((args.single as QueryPosition).value, env.prices);
    return value == null ? const QueryValue.null_() : QueryValue.amount(value);
  }),
  FuncSpec('value', <QueryType>[QueryType.position, QueryType.date], QueryType.amount, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Amount? value = marketValue((args[0] as QueryPosition).value, env.prices, (args[1] as QueryDate).value);
    return value == null ? const QueryValue.null_() : QueryValue.amount(value);
  }),
  FuncSpec(
    'value',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.inventory(reduceValue((args.single as QueryInventory).value, env.prices)),
  ),
  FuncSpec(
    'value',
    <QueryType>[QueryType.inventory, QueryType.date],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.inventory(
      reduceValue((args[0] as QueryInventory).value, env.prices, (args[1] as QueryDate).value),
    ),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.amount],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) => _convertAmount((args[0] as QueryAmount).value, env, null),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.amount, QueryType.text],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _convertAmount((args[0] as QueryAmount).value, env, args[1].asText()),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.position],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) => _convertPosition((args[0] as QueryPosition).value, env, null),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.position, QueryType.text],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _convertPosition((args[0] as QueryPosition).value, env, args[1].asText()),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _convertInventory((args[0] as QueryInventory).value, env, null),
  ),
  FuncSpec(
    'convert',
    <QueryType>[QueryType.inventory, QueryType.text],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _convertInventory((args[0] as QueryInventory).value, env, args[1].asText()),
  ),
  FuncSpec(
    'number',
    <QueryType>[QueryType.amount],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.number((args.single as QueryAmount).value.number),
  ),
  FuncSpec(
    'currency',
    <QueryType>[QueryType.amount],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.text((args.single as QueryAmount).value.currency.name),
  ),
  FuncSpec(
    'commodity',
    <QueryType>[QueryType.amount],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.text((args.single as QueryAmount).value.currency.name),
  ),
  FuncSpec(
    'only',
    <QueryType>[QueryType.text, QueryType.inventory],
    QueryType.amount,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.amount((args[1] as QueryInventory).value.currencyUnits(Currency(name: args[0].asText()!))),
  ),
  FuncSpec(
    'empty',
    <QueryType>[QueryType.inventory],
    QueryType.boolean,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.boolean((args.single as QueryInventory).value.isEmpty),
  ),
  FuncSpec('getprice', <QueryType>[QueryType.text, QueryType.text], QueryType.number, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Decimal? price = getPrice(env.prices, args[0].asText()!, args[1].asText()!);
    return price == null ? const QueryValue.null_() : QueryValue.number(price);
  }),
  FuncSpec('getprice', <QueryType>[QueryType.text, QueryType.text, QueryType.date], QueryType.number, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Decimal? price = getPrice(env.prices, args[0].asText()!, args[1].asText()!, (args[2] as QueryDate).value);
    return price == null ? const QueryValue.null_() : QueryValue.number(price);
  }),
  FuncSpec(
    'open_date',
    <QueryType>[QueryType.text],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) => _openCloseDate(env, args.single.asText()!, open: true),
    passContext: true,
  ),
  FuncSpec(
    'close_date',
    <QueryType>[QueryType.text],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) => _openCloseDate(env, args.single.asText()!, open: false),
    passContext: true,
  ),
  FuncSpec(
    'account_sortkey',
    <QueryType>[QueryType.text],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.text(accountSortKey(accountFor(args.single.asText() ?? '', env.options))),
    passContext: true,
  ),
  FuncSpec('safediv', <QueryType>[QueryType.number, QueryType.number], QueryType.number, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Decimal denom = (args[1] as QueryNumber).value;
    if (denom == Decimal.zero) return QueryValue.number(Decimal.zero);
    return QueryValue.number(((args[0] as QueryNumber).value / denom).toDecimal(scaleOnInfinitePrecision: 28));
  }),
  FuncSpec('date_diff', <QueryType>[QueryType.date, QueryType.date], QueryType.integer, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final BeanDate a = (args[0] as QueryDate).value;
    final BeanDate b = (args[1] as QueryDate).value;
    return QueryValue.integer(
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays,
    );
  }),
  FuncSpec(
    'date_add',
    <QueryType>[QueryType.date, QueryType.integer],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) =>
        QueryValue.date(addDays((args[0] as QueryDate).value, (args[1] as QueryInteger).value)),
  ),
  FuncSpec(
    'parse_date',
    <QueryType>[QueryType.text],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) => _toDate(args.single),
  ),
  FuncSpec('interval', <QueryType>[QueryType.text], QueryType.interval, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final DateDelta? delta = parseInterval(args.single.asText() ?? '');
    return delta == null ? const QueryValue.null_() : QueryValue.interval(delta);
  }),
  FuncSpec(
    'date_trunc',
    <QueryType>[QueryType.text, QueryType.date],
    QueryType.date,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _dateTrunc(args[0].asText() ?? '', (args[1] as QueryDate).value),
  ),
  FuncSpec(
    'date_part',
    <QueryType>[QueryType.text, QueryType.date],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) =>
        _datePart(args[0].asText() ?? '', (args[1] as QueryDate).value),
  ),
  FuncSpec('possign', <QueryType>[QueryType.number, QueryType.text], QueryType.number, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final int sign = accountSign(accountFor(args[1].asText() ?? '', env.options));
    final Decimal number = (args[0] as QueryNumber).value;
    return QueryValue.number(sign < 0 ? -number : number);
  }, passContext: true),
  FuncSpec(
    'joinstr',
    <QueryType>[QueryType.set],
    QueryType.text,
    (Object row, TableEnv env, List<QueryValue> args) => QueryValue.text(_setStrings(args.single).join(',')),
  ),
  FuncSpec('findfirst', <QueryType>[QueryType.text, QueryType.set], QueryType.text, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final RegExp pattern = RegExp(args[0].asText() ?? '');
    final List<String> values = _setStrings(args[1])..sort();
    for (final String value in values) {
      if (pattern.hasMatch(value)) return QueryValue.text(value);
    }
    return const QueryValue.null_();
  }),
  FuncSpec('filter_currency', <QueryType>[QueryType.position, QueryType.text], QueryType.position, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final Position position = (args[0] as QueryPosition).value;
    return position.units.currency.name == args[1].asText() ? args[0] : const QueryValue.null_();
  }),
  FuncSpec('filter_currency', <QueryType>[QueryType.inventory, QueryType.text], QueryType.inventory, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final String? currency = args[1].asText();
    final List<Position> filtered = <Position>[
      for (final Position position in (args[0] as QueryInventory).value.positions)
        if (position.units.currency.name == currency) position,
    ];
    return QueryValue.inventory(Inventory(positions: filtered));
  }),
  FuncSpec('coalesce', <QueryType>[QueryType.object], QueryType.object, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    for (final QueryValue arg in args) {
      if (!arg.isNull) return arg;
    }
    return const QueryValue.null_();
  }),
  FuncSpec(
    'count',
    <QueryType>[QueryType.asterisk],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => const QueryValue.integer(1),
    aggregate: true,
  ),
  FuncSpec(
    'count',
    <QueryType>[QueryType.object],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) =>
        args.single.isNull ? const QueryValue.integer(0) : const QueryValue.integer(1),
    aggregate: true,
  ),
  FuncSpec(
    'sum',
    <QueryType>[QueryType.integer],
    QueryType.integer,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec(
    'sum',
    <QueryType>[QueryType.number],
    QueryType.number,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec('sum', <QueryType>[QueryType.amount], QueryType.inventory, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    if (args.single.isNull) return const QueryValue.inventory(Inventory());
    return QueryValue.inventory(inventoryFromAmount((args.single as QueryAmount).value));
  }, aggregate: true),
  FuncSpec('sum', <QueryType>[QueryType.position], QueryType.inventory, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    if (args.single.isNull) return const QueryValue.inventory(Inventory());
    return QueryValue.inventory(inventoryFromPosition((args.single as QueryPosition).value));
  }, aggregate: true),
  FuncSpec(
    'sum',
    <QueryType>[QueryType.inventory],
    QueryType.inventory,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec(
    'min',
    <QueryType>[QueryType.object],
    QueryType.object,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec(
    'max',
    <QueryType>[QueryType.object],
    QueryType.object,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec(
    'first',
    <QueryType>[QueryType.object],
    QueryType.object,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec(
    'last',
    <QueryType>[QueryType.object],
    QueryType.object,
    (Object row, TableEnv env, List<QueryValue> args) => args.single,
    aggregate: true,
  ),
  FuncSpec('maxwidth', <QueryType>[QueryType.text, QueryType.integer], QueryType.text, (
    Object row,
    TableEnv env,
    List<QueryValue> args,
  ) {
    final String text = args[0].asText() ?? '';
    final int width = (args[1] as QueryInteger).value;
    if (text.length <= width) return QueryValue.text(text);
    if (width <= 3) return QueryValue.text(text.substring(0, width));
    return QueryValue.text('${text.substring(0, width - 3)}...');
  }),
];

QueryValue _toInt(QueryValue value) {
  try {
    return switch (value) {
      QueryNull() => const QueryValue.null_(),
      QueryInteger(:final int value) => QueryValue.integer(value),
      QueryBoolean(:final bool value) => QueryValue.integer(value ? 1 : 0),
      QueryNumber(:final Decimal value) => QueryValue.integer(value.toBigInt().toInt()),
      QueryText(:final String value) => QueryValue.integer(int.parse(value)),
      _ => const QueryValue.null_(),
    };
  } on Object {
    return const QueryValue.null_();
  }
}

QueryValue _toDecimal(QueryValue value) {
  try {
    return switch (value) {
      QueryNull() => const QueryValue.null_(),
      QueryNumber(:final Decimal value) => QueryValue.number(value),
      QueryInteger(:final int value) => QueryValue.number(Decimal.fromInt(value)),
      QueryBoolean(:final bool value) => QueryValue.number(Decimal.fromInt(value ? 1 : 0)),
      QueryText(:final String value) => QueryValue.number(Decimal.parse(value)),
      _ => const QueryValue.null_(),
    };
  } on Object {
    return const QueryValue.null_();
  }
}

QueryValue _toDate(QueryValue value) {
  try {
    return switch (value) {
      QueryDate() => value,
      QueryText(:final String value) => QueryValue.date(
        BeanDate(
          year: int.parse(value.substring(0, 4)),
          month: int.parse(value.substring(5, 7)),
          day: int.parse(value.substring(8, 10)),
        ),
      ),
      _ => const QueryValue.null_(),
    };
  } on Object {
    return const QueryValue.null_();
  }
}

String _stringify(QueryValue value) => switch (value) {
  QueryNull() => 'NULL',
  QueryBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
  QueryInteger(:final int value) => '$value',
  QueryNumber(:final Decimal value) => '$value',
  QueryText(:final String value) => value,
  QueryDate(:final BeanDate value) => '$value',
  QueryAccount(:final Account value) => value.name,
  QueryCurrency(:final Currency value) => value.name,
  QueryAmount(:final Amount value) => '$value',
  QueryPosition(:final Position value) => '$value',
  QueryInventory(:final Inventory value) => '$value',
  QueryFlag(:final Flag value) => flagChar(value),
  _ => value.toString(),
};

int _setLength(QueryValue value) => switch (value) {
  QueryTags(:final Set<Tag> value) => value.length,
  QueryLinks(:final Set<Link> value) => value.length,
  QueryAccounts(:final Set<Account> value) => value.length,
  QueryStringSet(:final Set<String> value) => value.length,
  QueryList(:final List<QueryValue> value) => value.length,
  QueryText(:final String value) => value.length,
  _ => 0,
};

List<String> _setStrings(QueryValue value) => switch (value) {
  QueryTags(:final Set<Tag> value) => <String>[for (final Tag tag in value) tag.name],
  QueryLinks(:final Set<Link> value) => <String>[for (final Link link in value) link.name],
  QueryAccounts(:final Set<Account> value) => <String>[for (final Account account in value) account.name],
  QueryStringSet(:final Set<String> value) => value.toList(),
  QueryList(:final List<QueryValue> value) => <String>[for (final QueryValue item in value) item.asText() ?? ''],
  _ => const <String>[],
};

QueryValue _openCloseDate(TableEnv env, String account, {required bool open}) {
  for (final Directive entry in env.directives) {
    if (open && entry.body is OpenBody && (entry.body as OpenBody).account.name == account) {
      return QueryValue.date(entry.date);
    }
    if (!open && entry.body is CloseBody && (entry.body as CloseBody).account.name == account) {
      return QueryValue.date(entry.date);
    }
  }
  return const QueryValue.null_();
}

QueryValue _dateTrunc(String field, BeanDate date) => switch (field) {
  'month' => QueryValue.date(BeanDate(year: date.year, month: date.month, day: 1)),
  'quarter' => QueryValue.date(BeanDate(year: date.year, month: date.month - (date.month - 1) % 3, day: 1)),
  'year' => QueryValue.date(BeanDate(year: date.year, month: 1, day: 1)),
  'decade' => QueryValue.date(BeanDate(year: date.year - date.year % 10, month: 1, day: 1)),
  'century' => QueryValue.date(BeanDate(year: date.year - (date.year - 1) % 100, month: 1, day: 1)),
  'millennium' => QueryValue.date(BeanDate(year: date.year - (date.year - 1) % 1000, month: 1, day: 1)),
  'week' => QueryValue.date(addDays(date, -(DateTime.utc(date.year, date.month, date.day).weekday - 1))),
  _ => const QueryValue.null_(),
};

QueryValue _datePart(String field, BeanDate date) {
  final DateTime native = DateTime.utc(date.year, date.month, date.day);
  return switch (field) {
    'weekday' || 'dow' => QueryValue.integer(native.weekday % 7),
    'isoweekday' || 'isodow' => QueryValue.integer(native.weekday),
    'week' => QueryValue.integer(_isoWeek(native)),
    'month' => QueryValue.integer(date.month),
    'quarter' => QueryValue.integer((date.month - 1) ~/ 3 + 1),
    'year' => QueryValue.integer(date.year),
    'isoyear' => QueryValue.integer(native.weekday == 7 && date.month == 1 && date.day < 4 ? date.year - 1 : date.year),
    'decade' => QueryValue.integer(date.year ~/ 10),
    'century' => QueryValue.integer((date.year - 1) ~/ 100 + 1),
    'millennium' => QueryValue.integer((date.year - 1) ~/ 1000 + 1),
    'epoch' => QueryValue.integer(native.difference(DateTime.utc(1970)).inSeconds),
    _ => const QueryValue.null_(),
  };
}

Currency? _targetCurrency(TableEnv env, String? named) {
  if (named != null) {
    return Currency(name: named);
  }
  if (env.options.operatingCurrency.isEmpty) {
    return null;
  }
  return env.options.operatingCurrency.first;
}

QueryValue _convertAmount(Amount amount, TableEnv env, String? named) {
  final Currency? target = _targetCurrency(env, named);
  if (target == null) return const QueryValue.null_();
  final Amount? converted = convertAmount(amount, target, env.prices);
  return converted == null ? const QueryValue.null_() : QueryValue.amount(converted);
}

QueryValue _convertPosition(Position position, TableEnv env, String? named) {
  final Currency? target = _targetCurrency(env, named);
  if (target == null) return const QueryValue.null_();
  final Amount? converted = convertPosition(position, target, env.prices);
  return converted == null ? const QueryValue.null_() : QueryValue.amount(converted);
}

QueryValue _convertInventory(Inventory inventory, TableEnv env, String? named) {
  final Currency? target = _targetCurrency(env, named);
  if (target == null) return const QueryValue.null_();
  return QueryValue.inventory(reduceConvert(inventory, target, env.prices));
}

int _isoWeek(DateTime date) {
  final DateTime thursday = date.add(Duration(days: 4 - date.weekday));
  final DateTime first = DateTime.utc(thursday.year);
  return 1 + thursday.difference(first).inDays ~/ 7;
}

bool isTruthy(QueryValue value) => switch (value) {
  QueryNull() => false,
  QueryBoolean(:final bool value) => value,
  QueryInteger(:final int value) => value != 0,
  QueryNumber(:final Decimal value) => value != Decimal.zero,
  QueryText(:final String value) => value.isNotEmpty,
  _ => true,
};

QueryValue metaLookup(Meta meta, String key, [QueryValue? fallback]) {
  final MetaValue? value = meta.lookup(key);
  if (value != null) return QueryValue.metaValue(value);
  return fallback ?? const QueryValue.null_();
}

Set<String> membershipStrings(QueryValue value) => switch (value) {
  QueryTags(:final Set<Tag> value) => <String>{for (final Tag tag in value) tag.name},
  QueryLinks(:final Set<Link> value) => <String>{for (final Link link in value) link.name},
  QueryAccounts(:final Set<Account> value) => <String>{for (final Account account in value) account.name},
  QueryStringSet(:final Set<String> value) => value,
  QueryList(:final List<QueryValue> value) => <String>{
    for (final QueryValue item in value) item.asText() ?? _stringify(item),
  },
  QueryText(:final String value) => <String>{value},
  QueryAccount(:final Account value) => <String>{value.name},
  _ => <String>{if (!value.isNull) _stringify(value)},
};
