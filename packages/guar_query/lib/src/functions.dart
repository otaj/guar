// Function and operator evaluation for compiled BQL expressions.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'convert.dart';
import 'helpers.dart';
import 'tables.dart';
import 'value.dart';

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

List<FuncSpec> builtinFunctions() {
  return [
    FuncSpec('bool', [QueryType.object], QueryType.boolean, (row, env, args) {
      if (args.single.isNull) return const QueryValue.null_();
      return QueryValue.boolean(isTruthy(args.single));
    }),
    FuncSpec('int', [QueryType.object], QueryType.integer, (row, env, args) => _toInt(args.single)),
    FuncSpec('decimal', [QueryType.object], QueryType.number, (row, env, args) => _toDecimal(args.single)),
    FuncSpec('str', [QueryType.object], QueryType.text, (row, env, args) => QueryValue.text(_stringify(args.single))),
    FuncSpec('date', [QueryType.object], QueryType.date, (row, env, args) => _toDate(args.single)),
    FuncSpec('date', [QueryType.integer, QueryType.integer, QueryType.integer], QueryType.date, (row, env, args) {
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
      [QueryType.integer],
      QueryType.integer,
      (row, env, args) => QueryValue.integer(-(args.single as QueryInteger).value),
    ),
    FuncSpec(
      'neg',
      [QueryType.number],
      QueryType.number,
      (row, env, args) => QueryValue.number(-(args.single as QueryNumber).value),
    ),
    FuncSpec(
      'neg',
      [QueryType.amount],
      QueryType.amount,
      (row, env, args) => QueryValue.amount(-(args.single as QueryAmount).value),
    ),
    FuncSpec(
      'neg',
      [QueryType.position],
      QueryType.position,
      (row, env, args) => QueryValue.position(-(args.single as QueryPosition).value),
    ),
    FuncSpec(
      'neg',
      [QueryType.inventory],
      QueryType.inventory,
      (row, env, args) => QueryValue.inventory(-(args.single as QueryInventory).value),
    ),
    FuncSpec('abs', [QueryType.number], QueryType.number, (row, env, args) {
      final number = (args.single as QueryNumber).value;
      return QueryValue.number(number < Decimal.zero ? -number : number);
    }),
    FuncSpec(
      'abs',
      [QueryType.position],
      QueryType.position,
      (row, env, args) => QueryValue.position((args.single as QueryPosition).value.absolute),
    ),
    FuncSpec(
      'abs',
      [QueryType.inventory],
      QueryType.inventory,
      (row, env, args) => QueryValue.inventory((args.single as QueryInventory).value.absolute),
    ),
    FuncSpec('round', [QueryType.number], QueryType.number, (row, env, args) {
      return QueryValue.number((args.single as QueryNumber).value.round());
    }),
    FuncSpec('round', [QueryType.number, QueryType.integer], QueryType.number, (row, env, args) {
      return QueryValue.number((args[0] as QueryNumber).value.round(scale: (args[1] as QueryInteger).value));
    }),
    FuncSpec(
      'length',
      [QueryType.text],
      QueryType.integer,
      (row, env, args) => QueryValue.integer((args.single.asText() ?? '').length),
    ),
    FuncSpec(
      'length',
      [QueryType.set],
      QueryType.integer,
      (row, env, args) => QueryValue.integer(_setLength(args.single)),
    ),
    FuncSpec(
      'year',
      [QueryType.date],
      QueryType.integer,
      (row, env, args) => QueryValue.integer((args.single as QueryDate).value.year),
    ),
    FuncSpec(
      'month',
      [QueryType.date],
      QueryType.integer,
      (row, env, args) => QueryValue.integer((args.single as QueryDate).value.month),
    ),
    FuncSpec(
      'day',
      [QueryType.date],
      QueryType.integer,
      (row, env, args) => QueryValue.integer((args.single as QueryDate).value.day),
    ),
    FuncSpec('yearmonth', [QueryType.date], QueryType.date, (row, env, args) {
      final date = (args.single as QueryDate).value;
      return QueryValue.date(BeanDate(year: date.year, month: date.month, day: 1));
    }),
    FuncSpec('quarter', [QueryType.date], QueryType.text, (row, env, args) {
      final date = (args.single as QueryDate).value;
      return QueryValue.text('${date.year.toString().padLeft(4, '0')}-Q${(date.month - 1) ~/ 3 + 1}');
    }),
    FuncSpec('weekday', [QueryType.date], QueryType.text, (row, env, args) {
      final date = (args.single as QueryDate).value;
      return QueryValue.text(
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.utc(date.year, date.month, date.day).weekday - 1],
      );
    }),
    FuncSpec('today', [], QueryType.date, (row, env, args) {
      final now = env.clock();
      return QueryValue.date(BeanDate(year: now.year, month: now.month, day: now.day));
    }),
    FuncSpec(
      'root',
      [QueryType.text],
      QueryType.text,
      (row, env, args) => QueryValue.text(rootAccount(args.single.asText() ?? '', 1)),
    ),
    FuncSpec('root', [QueryType.text, QueryType.integer], QueryType.text, (row, env, args) {
      return QueryValue.text(rootAccount(args[0].asText() ?? '', (args[1] as QueryInteger).value));
    }),
    FuncSpec(
      'parent',
      [QueryType.text],
      QueryType.text,
      (row, env, args) => QueryValue.text(parentAccount(args.single.asText() ?? '')),
    ),
    FuncSpec(
      'leaf',
      [QueryType.text],
      QueryType.text,
      (row, env, args) => QueryValue.text(leafAccount(args.single.asText() ?? '')),
    ),
    FuncSpec(
      'upper',
      [QueryType.text],
      QueryType.text,
      (row, env, args) => QueryValue.text((args.single.asText() ?? '').toUpperCase()),
    ),
    FuncSpec(
      'lower',
      [QueryType.text],
      QueryType.text,
      (row, env, args) => QueryValue.text((args.single.asText() ?? '').toLowerCase()),
    ),
    FuncSpec('substr', [QueryType.text, QueryType.integer, QueryType.integer], QueryType.text, (row, env, args) {
      final text = args[0].asText() ?? '';
      final start = (args[1] as QueryInteger).value;
      final end = (args[2] as QueryInteger).value;
      final from = start < 0 ? 0 : start;
      final to = end > text.length ? text.length : end;
      if (from >= to) return const QueryValue.text('');
      return QueryValue.text(text.substring(from, to));
    }),
    FuncSpec(
      'units',
      [QueryType.position],
      QueryType.amount,
      (row, env, args) => QueryValue.amount(unitsOf((args.single as QueryPosition).value)),
    ),
    FuncSpec(
      'units',
      [QueryType.inventory],
      QueryType.inventory,
      (row, env, args) => QueryValue.inventory(reduceUnits((args.single as QueryInventory).value)),
    ),
    FuncSpec(
      'cost',
      [QueryType.position],
      QueryType.amount,
      (row, env, args) => QueryValue.amount(costOf((args.single as QueryPosition).value)),
    ),
    FuncSpec(
      'cost',
      [QueryType.inventory],
      QueryType.inventory,
      (row, env, args) => QueryValue.inventory(reduceCost((args.single as QueryInventory).value)),
    ),
    FuncSpec('weight', [QueryType.position], QueryType.amount, (row, env, args) {
      if (row is PostingRow) return QueryValue.amount(weightOf(row.posting));
      return QueryValue.amount(costOf((args.single as QueryPosition).value));
    }),
    FuncSpec('value', [QueryType.position], QueryType.amount, (row, env, args) {
      final value = marketValue((args.single as QueryPosition).value, env.prices);
      return value == null ? const QueryValue.null_() : QueryValue.amount(value);
    }),
    FuncSpec('value', [QueryType.position, QueryType.date], QueryType.amount, (row, env, args) {
      final value = marketValue((args[0] as QueryPosition).value, env.prices, (args[1] as QueryDate).value);
      return value == null ? const QueryValue.null_() : QueryValue.amount(value);
    }),
    FuncSpec('value', [QueryType.inventory], QueryType.inventory, (row, env, args) {
      return QueryValue.inventory(reduceValue((args.single as QueryInventory).value, env.prices));
    }),
    FuncSpec('value', [QueryType.inventory, QueryType.date], QueryType.inventory, (row, env, args) {
      return QueryValue.inventory(
        reduceValue((args[0] as QueryInventory).value, env.prices, (args[1] as QueryDate).value),
      );
    }),
    FuncSpec('convert', [QueryType.amount, QueryType.text], QueryType.amount, (row, env, args) {
      final converted = convertAmount((args[0] as QueryAmount).value, Currency(name: args[1].asText()!), env.prices);
      return converted == null ? const QueryValue.null_() : QueryValue.amount(converted);
    }),
    FuncSpec('convert', [QueryType.position, QueryType.text], QueryType.amount, (row, env, args) {
      final converted = convertPosition(
        (args[0] as QueryPosition).value,
        Currency(name: args[1].asText()!),
        env.prices,
      );
      return converted == null ? const QueryValue.null_() : QueryValue.amount(converted);
    }),
    FuncSpec('convert', [QueryType.inventory, QueryType.text], QueryType.inventory, (row, env, args) {
      return QueryValue.inventory(
        reduceConvert((args[0] as QueryInventory).value, Currency(name: args[1].asText()!), env.prices),
      );
    }),
    FuncSpec(
      'number',
      [QueryType.amount],
      QueryType.number,
      (row, env, args) => QueryValue.number((args.single as QueryAmount).value.number),
    ),
    FuncSpec(
      'currency',
      [QueryType.amount],
      QueryType.text,
      (row, env, args) => QueryValue.text((args.single as QueryAmount).value.currency.name),
    ),
    FuncSpec(
      'commodity',
      [QueryType.amount],
      QueryType.text,
      (row, env, args) => QueryValue.text((args.single as QueryAmount).value.currency.name),
    ),
    FuncSpec('only', [QueryType.text, QueryType.inventory], QueryType.amount, (row, env, args) {
      return QueryValue.amount((args[1] as QueryInventory).value.currencyUnits(Currency(name: args[0].asText()!)));
    }),
    FuncSpec(
      'empty',
      [QueryType.inventory],
      QueryType.boolean,
      (row, env, args) => QueryValue.boolean((args.single as QueryInventory).value.isEmpty),
    ),
    FuncSpec('getprice', [QueryType.text, QueryType.text], QueryType.number, (row, env, args) {
      final price = getPrice(env.prices, args[0].asText()!, args[1].asText()!);
      return price == null ? const QueryValue.null_() : QueryValue.number(price);
    }),
    FuncSpec('getprice', [QueryType.text, QueryType.text, QueryType.date], QueryType.number, (row, env, args) {
      final price = getPrice(env.prices, args[0].asText()!, args[1].asText()!, (args[2] as QueryDate).value);
      return price == null ? const QueryValue.null_() : QueryValue.number(price);
    }),
    FuncSpec('open_date', [QueryType.text], QueryType.date, (row, env, args) {
      return _openCloseDate(env, args.single.asText()!, open: true);
    }, passContext: true),
    FuncSpec('close_date', [QueryType.text], QueryType.date, (row, env, args) {
      return _openCloseDate(env, args.single.asText()!, open: false);
    }, passContext: true),
    FuncSpec('account_sortkey', [QueryType.text], QueryType.text, (row, env, args) {
      return QueryValue.text(accountSortKey(accountFor(args.single.asText() ?? '', env.options)));
    }, passContext: true),
    FuncSpec('safediv', [QueryType.number, QueryType.number], QueryType.number, (row, env, args) {
      final denom = (args[1] as QueryNumber).value;
      if (denom == Decimal.zero) return QueryValue.number(Decimal.zero);
      return QueryValue.number(((args[0] as QueryNumber).value / denom).toDecimal(scaleOnInfinitePrecision: 28));
    }),
    FuncSpec('date_diff', [QueryType.date, QueryType.date], QueryType.integer, (row, env, args) {
      final a = (args[0] as QueryDate).value;
      final b = (args[1] as QueryDate).value;
      return QueryValue.integer(
        DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays,
      );
    }),
    FuncSpec('date_add', [QueryType.date, QueryType.integer], QueryType.date, (row, env, args) {
      return QueryValue.date(addDays((args[0] as QueryDate).value, (args[1] as QueryInteger).value));
    }),
    FuncSpec('parse_date', [QueryType.text], QueryType.date, (row, env, args) => _toDate(args.single)),
    FuncSpec('interval', [QueryType.text], QueryType.interval, (row, env, args) {
      final delta = parseInterval(args.single.asText() ?? '');
      return delta == null ? const QueryValue.null_() : QueryValue.interval(delta);
    }),
    FuncSpec('date_trunc', [QueryType.text, QueryType.date], QueryType.date, (row, env, args) {
      return _dateTrunc(args[0].asText() ?? '', (args[1] as QueryDate).value);
    }),
    FuncSpec('date_part', [QueryType.text, QueryType.date], QueryType.integer, (row, env, args) {
      return _datePart(args[0].asText() ?? '', (args[1] as QueryDate).value);
    }),
    FuncSpec('possign', [QueryType.number, QueryType.text], QueryType.number, (row, env, args) {
      final sign = accountSign(accountFor(args[1].asText() ?? '', env.options));
      final number = (args[0] as QueryNumber).value;
      return QueryValue.number(sign < 0 ? -number : number);
    }, passContext: true),
    FuncSpec(
      'joinstr',
      [QueryType.set],
      QueryType.text,
      (row, env, args) => QueryValue.text(_setStrings(args.single).join(',')),
    ),
    FuncSpec('findfirst', [QueryType.text, QueryType.set], QueryType.text, (row, env, args) {
      final pattern = RegExp(args[0].asText() ?? '');
      final values = _setStrings(args[1])..sort();
      for (final value in values) {
        if (pattern.hasMatch(value)) return QueryValue.text(value);
      }
      return const QueryValue.null_();
    }),
    FuncSpec('filter_currency', [QueryType.position, QueryType.text], QueryType.position, (row, env, args) {
      final position = (args[0] as QueryPosition).value;
      return position.units.currency.name == args[1].asText() ? args[0] : const QueryValue.null_();
    }),
    FuncSpec('filter_currency', [QueryType.inventory, QueryType.text], QueryType.inventory, (row, env, args) {
      final currency = args[1].asText();
      final filtered = [
        for (final position in (args[0] as QueryInventory).value.positions)
          if (position.units.currency.name == currency) position,
      ];
      return QueryValue.inventory(Inventory(positions: filtered));
    }),
    FuncSpec('coalesce', [QueryType.object], QueryType.object, (row, env, args) {
      for (final arg in args) {
        if (!arg.isNull) return arg;
      }
      return const QueryValue.null_();
    }),
    FuncSpec(
      'count',
      [QueryType.asterisk],
      QueryType.integer,
      (row, env, args) => const QueryValue.integer(1),
      aggregate: true,
    ),
    FuncSpec(
      'count',
      [QueryType.object],
      QueryType.integer,
      (row, env, args) => args.single.isNull ? const QueryValue.integer(0) : const QueryValue.integer(1),
      aggregate: true,
    ),
    FuncSpec('sum', [QueryType.integer], QueryType.integer, (row, env, args) => args.single, aggregate: true),
    FuncSpec('sum', [QueryType.number], QueryType.number, (row, env, args) => args.single, aggregate: true),
    FuncSpec('sum', [QueryType.amount], QueryType.inventory, (row, env, args) {
      if (args.single.isNull) return const QueryValue.inventory(Inventory());
      return QueryValue.inventory(inventoryFromAmount((args.single as QueryAmount).value));
    }, aggregate: true),
    FuncSpec('sum', [QueryType.position], QueryType.inventory, (row, env, args) {
      if (args.single.isNull) return const QueryValue.inventory(Inventory());
      return QueryValue.inventory(inventoryFromPosition((args.single as QueryPosition).value));
    }, aggregate: true),
    FuncSpec('sum', [QueryType.inventory], QueryType.inventory, (row, env, args) => args.single, aggregate: true),
    FuncSpec('min', [QueryType.object], QueryType.object, (row, env, args) => args.single, aggregate: true),
    FuncSpec('max', [QueryType.object], QueryType.object, (row, env, args) => args.single, aggregate: true),
    FuncSpec('first', [QueryType.object], QueryType.object, (row, env, args) => args.single, aggregate: true),
    FuncSpec('last', [QueryType.object], QueryType.object, (row, env, args) => args.single, aggregate: true),
    FuncSpec('maxwidth', [QueryType.text, QueryType.integer], QueryType.text, (row, env, args) {
      final text = args[0].asText() ?? '';
      final width = (args[1] as QueryInteger).value;
      if (text.length <= width) return QueryValue.text(text);
      if (width <= 3) return QueryValue.text(text.substring(0, width));
      return QueryValue.text('${text.substring(0, width - 3)}...');
    }),
  ];
}

QueryValue _toInt(QueryValue value) {
  try {
    return switch (value) {
      QueryNull() => const QueryValue.null_(),
      QueryInteger(:final value) => QueryValue.integer(value),
      QueryBoolean(:final value) => QueryValue.integer(value ? 1 : 0),
      QueryNumber(:final value) => QueryValue.integer(value.toBigInt().toInt()),
      QueryText(:final value) => QueryValue.integer(int.parse(value)),
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
      QueryNumber(:final value) => QueryValue.number(value),
      QueryInteger(:final value) => QueryValue.number(Decimal.fromInt(value)),
      QueryBoolean(:final value) => QueryValue.number(Decimal.fromInt(value ? 1 : 0)),
      QueryText(:final value) => QueryValue.number(Decimal.parse(value)),
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
      QueryText(:final value) => QueryValue.date(
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
  QueryBoolean(:final value) => value ? 'TRUE' : 'FALSE',
  QueryInteger(:final value) => '$value',
  QueryNumber(:final value) => '$value',
  QueryText(:final value) => value,
  QueryDate(:final value) => '$value',
  QueryAccount(:final value) => value.name,
  QueryCurrency(:final value) => value.name,
  QueryAmount(:final value) => '$value',
  QueryPosition(:final value) => '$value',
  QueryInventory(:final value) => '$value',
  QueryFlag(:final value) => flagChar(value),
  _ => value.toString(),
};

int _setLength(QueryValue value) => switch (value) {
  QueryTags(:final value) => value.length,
  QueryLinks(:final value) => value.length,
  QueryAccounts(:final value) => value.length,
  QueryStringSet(:final value) => value.length,
  QueryList(:final value) => value.length,
  QueryText(:final value) => value.length,
  _ => 0,
};

List<String> _setStrings(QueryValue value) => switch (value) {
  QueryTags(:final value) => [for (final tag in value) tag.name],
  QueryLinks(:final value) => [for (final link in value) link.name],
  QueryAccounts(:final value) => [for (final account in value) account.name],
  QueryStringSet(:final value) => value.toList(),
  QueryList(:final value) => [for (final item in value) item.asText() ?? ''],
  _ => const [],
};

QueryValue _openCloseDate(TableEnv env, String account, {required bool open}) {
  for (final entry in env.directives) {
    if (open && entry.body is OpenBody && (entry.body as OpenBody).account.name == account) {
      return QueryValue.date(entry.date);
    }
    if (!open && entry.body is CloseBody && (entry.body as CloseBody).account.name == account) {
      return QueryValue.date(entry.date);
    }
  }
  return const QueryValue.null_();
}

QueryValue _dateTrunc(String field, BeanDate date) {
  return switch (field) {
    'month' => QueryValue.date(BeanDate(year: date.year, month: date.month, day: 1)),
    'quarter' => QueryValue.date(BeanDate(year: date.year, month: date.month - (date.month - 1) % 3, day: 1)),
    'year' => QueryValue.date(BeanDate(year: date.year, month: 1, day: 1)),
    'decade' => QueryValue.date(BeanDate(year: date.year - date.year % 10, month: 1, day: 1)),
    'century' => QueryValue.date(BeanDate(year: date.year - (date.year - 1) % 100, month: 1, day: 1)),
    'millennium' => QueryValue.date(BeanDate(year: date.year - (date.year - 1) % 1000, month: 1, day: 1)),
    'week' => QueryValue.date(addDays(date, -(DateTime.utc(date.year, date.month, date.day).weekday - 1))),
    _ => const QueryValue.null_(),
  };
}

QueryValue _datePart(String field, BeanDate date) {
  final native = DateTime.utc(date.year, date.month, date.day);
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
    'epoch' => QueryValue.integer(native.difference(DateTime.utc(1970, 1, 1)).inSeconds),
    _ => const QueryValue.null_(),
  };
}

int _isoWeek(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final first = DateTime.utc(thursday.year, 1, 1);
  return 1 + thursday.difference(first).inDays ~/ 7;
}

bool isTruthy(QueryValue value) => switch (value) {
  QueryNull() => false,
  QueryBoolean(:final value) => value,
  QueryInteger(:final value) => value != 0,
  QueryNumber(:final value) => value != Decimal.zero,
  QueryText(:final value) => value.isNotEmpty,
  _ => true,
};

QueryValue metaLookup(Meta meta, String key, [QueryValue? fallback]) {
  for (final entry in meta.entries) {
    if (entry.key == key) {
      final value = entry.value;
      if (value == null) return const QueryValue.null_();
      return QueryValue.metaValue(value);
    }
  }
  return fallback ?? const QueryValue.null_();
}

Set<String> membershipStrings(QueryValue value) => switch (value) {
  QueryTags(:final value) => {for (final tag in value) tag.name},
  QueryLinks(:final value) => {for (final link in value) link.name},
  QueryAccounts(:final value) => {for (final account in value) account.name},
  QueryStringSet(:final value) => value,
  QueryList(:final value) => {for (final item in value) item.asText() ?? _stringify(item)},
  QueryText(:final value) => {value},
  QueryAccount(:final value) => {value.name},
  _ => {if (!value.isNull) _stringify(value)},
};
