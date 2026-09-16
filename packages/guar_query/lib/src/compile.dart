// Compile a BQL AST against Beancount tables and execute it.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'ast.dart';
import 'functions.dart';
import 'helpers.dart';
import 'result.dart';
import 'tables.dart';
import 'value.dart';

QueryResult compileAndExecute(
  Statement statement,
  Ledger ledger, {
  Object? params,
  required DateTime Function() clock,
}) {
  if (ledger is LedgerErrors) {
    return QueryResult.errors([
      for (final error in ledger.errors) QueryError(message: error.message, location: error.location),
    ]);
  }
  final env = TableEnv(ledger, clock: clock);
  final tables = beancountTables(env);
  final compiler = _Compiler(env, tables, params: params);
  return compiler.run(statement);
}

class _CompiledSelect {
  _CompiledSelect({
    required this.table,
    required this.targets,
    required this.where,
    required this.groupIndexes,
    required this.havingIndex,
    required this.orderSpec,
    required this.limit,
    required this.distinct,
    required this.pivot,
  });

  final BqlTable table;
  final List<_Target> targets;
  final _Eval? where;
  final List<int>? groupIndexes;
  final int? havingIndex;
  final List<(int, Ordering)>? orderSpec;
  final int? limit;
  final bool distinct;
  final List<int>? pivot;
}

class _Target {
  _Target(this.eval, this.name, this.type, {String? key}) : key = key ?? name;
  final _Eval eval;
  final String? name;
  final String? key;
  final QueryType type;
  bool get isAggregate => eval.isAggregate;
}

abstract class _Eval {
  QueryType get type;
  bool get isAggregate => false;
  QueryValue call(Object row);
  List<_Eval> get children => const [];
}

class _Compiler {
  _Compiler(this.env, this.tables, {this.params}) : functions = builtinFunctions() {
    table = tables['']!;
  }

  final TableEnv env;
  final Map<String, BqlTable> tables;
  final Object? params;
  final List<FuncSpec> functions;
  late BqlTable table;
  _BalanceWindow? _balanceWindow;

  QueryResult run(Statement statement) {
    switch (statement) {
      case CreateTableStatement():
        throw QueryException('CREATE TABLE is not supported');
      case InsertStatement():
        throw QueryException('INSERT is not supported');
      case PrintStatement(:final fromClause):
        return _runPrint(fromClause);
      case BalancesStatement():
        return run(_desugarBalances(statement));
      case JournalStatement():
        return run(_desugarJournal(statement));
      case SelectStatement():
        final compiled = _compileSelect(statement);
        var result = _execute(compiled);
        if (compiled.pivot != null && result is QueryTable) {
          result = _pivot(result, compiled.pivot!);
        }
        return result;
    }
  }

  QueryResult _runPrint(FromClause? fromClause) {
    table = tables['entries']!;
    final where = _compileFrom(fromClause);
    final entries = <Directive>[
      for (final row in table.rows())
        if (where == null || isTruthy(where.call(row))) row as Directive,
    ];
    return QueryResult.entries(entries);
  }

  _CompiledSelect _compileSelect(SelectStatement node) {
    final previous = table;
    final previousWindow = _balanceWindow;
    _balanceWindow = _BalanceWindow();
    final fromWhere = _compileFrom(node.fromClause);
    final targets = _compileTargets(node.targets);
    var where = node.whereClause == null ? null : compileExpr(node.whereClause!);
    if (where != null && where.isAggregate) {
      throw QueryException('aggregates are not allowed in WHERE clause');
    }
    if (fromWhere != null) {
      where = where == null ? fromWhere : _And([fromWhere, where]);
    }
    final grouped = _compileGroupBy(node.groupBy, targets);
    targets.addAll(grouped.$1);
    final ordered = _compileOrderBy(node.orderBy, targets);
    targets.addAll(ordered.$1);
    final groupIndexes = grouped.$2;
    if (groupIndexes != null) {
      final nonAgg = {
        for (var i = 0; i < targets.length; i++)
          if (!targets[i].isAggregate) i,
      };
      if (nonAgg.difference(groupIndexes.toSet()).isNotEmpty) {
        throw QueryException('all non-aggregates must be covered by GROUP-BY clause in aggregate query');
      }
      _balanceWindow!.partition = [
        for (final index in groupIndexes)
          if (!_isDateDerived(targets[index].eval)) targets[index].eval,
      ];
    } else if (targets.any((target) => target.isAggregate)) {
      final nonAgg = [
        for (var i = 0; i < targets.length; i++)
          if (!targets[i].isAggregate) i,
      ];
      if (nonAgg.isNotEmpty) {
        throw QueryException('all non-aggregates must be covered by GROUP-BY clause in aggregate query');
      }
    }
    final pivot = _compilePivot(node.pivotBy, targets, grouped.$2);
    final compiled = _CompiledSelect(
      table: table,
      targets: targets,
      where: where,
      groupIndexes: grouped.$2 ?? (targets.any((t) => t.isAggregate) ? <int>[] : null),
      havingIndex: grouped.$3,
      orderSpec: ordered.$2,
      limit: node.limit,
      distinct: node.distinct == true,
      pivot: pivot,
    );
    table = previous;
    _balanceWindow = previousWindow;
    return compiled;
  }

  _Eval? _compileFrom(FromClause? node) {
    if (node == null) return null;
    switch (node) {
      case SubselectFrom(:final select):
        final result = _compileSelect(select);
        final executed = _execute(result);
        if (executed is! QueryTable) {
          throw QueryException('subquery did not produce a table');
        }
        table = _ResultTable(executed);
        return null;
      case TableFrom(:final name):
        final found = tables[name];
        if (found == null) {
          throw QueryException('table "$name" does not exist');
        }
        table = found;
        return null;
      case FilterFrom(:final expression, :final open, :final close, :final clear):
        if (expression is ColumnExpr) {
          final column = table.columns[expression.name];
          if (column == null) {
            final found = tables[expression.name];
            if (found != null) {
              table = found;
              if (open != null || close != null || clear == true) {
                table = table.evolve(open: open, close: close, clear: clear);
              }
              return null;
            }
          }
        }
        if (open != null || close != null || clear == true) {
          table = table.evolve(open: open, close: close, clear: clear);
        }
        if (expression == null) return null;
        final current = table;
        if (current is PostingsTable) {
          final entries = EntriesTable(current.env, open: current.open, close: current.close, clear: current.clear);
          table = entries;
          final compiled = compileExpr(expression);
          table = current;
          if (compiled.isAggregate) {
            throw QueryException('aggregates are not allowed in FROM clause');
          }
          final kept = <Directive>[
            for (final row in entries.rows())
              if (isTruthy(compiled.call(row))) row as Directive,
          ];
          table = PostingsTable(current.env.withDirectives(kept));
          return null;
        }
        final compiled = compileExpr(expression);
        if (compiled.isAggregate) {
          throw QueryException('aggregates are not allowed in FROM clause');
        }
        return compiled;
    }
  }

  List<_Target> _compileTargets(Object targets) {
    if (targets is Asterisk) {
      return [
        for (final name in table.wildcardColumns)
          _Target(_Column(table.columns[name]!, name: name), name, table.columns[name]!.type),
      ];
    }
    final list = targets as List<Target>;
    return [for (final target in list) _compileTarget(target)];
  }

  _Target _compileTarget(Target target) {
    final compiled = compileExpr(target.expression);
    return _Target(compiled, _targetName(target), compiled.type, key: target.name ?? _exprLabel(target.expression));
  }

  String? _targetName(Target target) {
    if (target.name != null) return target.name;
    final expr = target.expression;
    if (expr is ColumnExpr) return expr.name;
    return _exprLabel(expr);
  }

  (List<_Target>, List<int>?, int?) _compileGroupBy(GroupBy? groupBy, List<_Target> targets) {
    final aggregateQuery = targets.any((target) => target.isAggregate) || groupBy != null;
    if (!aggregateQuery) return (const [], null, null);
    final indexes = <int>[];
    final extra = <_Target>[];
    if (groupBy != null) {
      for (final column in groupBy.columns) {
        if (column is int) {
          if (column < 1 || column > targets.length) {
            throw QueryException('invalid GROUP BY index');
          }
          indexes.add(column - 1);
          continue;
        }
        final expr = column as Expr;
        final compiled = compileExpr(expr);
        final existing = _findTarget(targets, expr);
        if (existing != null) {
          indexes.add(existing);
        } else {
          indexes.add(targets.length + extra.length);
          extra.add(_Target(compiled, null, compiled.type, key: _exprLabel(expr)));
        }
      }
    } else {
      for (var i = 0; i < targets.length; i++) {
        if (!targets[i].isAggregate) indexes.add(i);
      }
    }
    int? havingIndex;
    if (groupBy?.having != null) {
      final compiled = compileExpr(groupBy!.having!);
      havingIndex = targets.length + extra.length;
      extra.add(_Target(compiled, null, compiled.type, key: _exprLabel(groupBy.having!)));
    }
    return (extra, indexes, havingIndex);
  }

  (List<_Target>, List<(int, Ordering)>?) _compileOrderBy(List<OrderBy>? orderBy, List<_Target> targets) {
    if (orderBy == null) return (const [], null);
    final spec = <(int, Ordering)>[];
    final extra = <_Target>[];
    for (final item in orderBy) {
      if (item.column is int) {
        spec.add(((item.column as int) - 1, item.ordering));
        continue;
      }
      final expr = item.column as Expr;
      final compiled = compileExpr(expr);
      final existing = _findTarget(targets, expr);
      if (existing != null) {
        spec.add((existing, item.ordering));
      } else {
        spec.add((targets.length + extra.length, item.ordering));
        extra.add(_Target(compiled, null, compiled.type, key: _exprLabel(expr)));
      }
    }
    return (extra, spec);
  }

  List<int>? _compilePivot(PivotBy? pivotBy, List<_Target> targets, List<int>? groupIndexes) {
    if (pivotBy == null) return null;
    final indexes = <int>[];
    for (final column in pivotBy.columns) {
      if (column is int) {
        indexes.add(column - 1);
      } else if (column is ColumnExpr) {
        final found = targets.indexWhere((target) => target.name == column.name);
        if (found < 0) throw QueryException('unknown PIVOT BY column');
        indexes.add(found);
      }
    }
    return indexes;
  }

  int? _findTarget(List<_Target> targets, Expr expr) {
    if (expr is ColumnExpr) {
      final named = targets.indexWhere((target) => target.name == expr.name);
      if (named >= 0) return named;
    }
    final label = _exprLabel(expr);
    final keyed = targets.indexWhere((target) => target.key == label);
    if (keyed >= 0) return keyed;
    return null;
  }

  _Eval compileExpr(Expr expr) {
    switch (expr) {
      case ColumnExpr(:final name):
        final column = table.columns[name];
        if (column == null) throw QueryException('column "$name" does not exist');
        if (name == 'balance' && table is PostingsTable) {
          return _Balance(_balanceWindow ??= _BalanceWindow());
        }
        return _Column(column, name: name);
      case ConstantExpr(:final value):
        final queryValue = queryValueFromLiteral(value);
        return _Constant(queryValue);
      case PlaceholderExpr(:final name):
        return _Constant(_resolveParam(name));
      case AsteriskExpr():
        return _Constant(const QueryValue.null_(), type: QueryType.asterisk);
      case FunctionExpr(:final fname, :final operands):
        return _compileFunction(fname, operands);
      case AttributeExpr(:final operand, :final name):
        return _Attribute(compileExpr(operand), name);
      case SubscriptExpr(:final operand, :final key):
        return _Subscript(compileExpr(operand), key);
      case SelectExpr(:final select):
        return _Subquery(this, select);
      case NotExpr(:final operand):
        return _Not(compileExpr(operand));
      case IsNullExpr(:final operand):
        return _IsNull(compileExpr(operand), not: false);
      case IsNotNullExpr(:final operand):
        return _IsNull(compileExpr(operand), not: true);
      case NegExpr(:final operand):
        return _compileFunction('neg', [operand]);
      case AndExpr(:final args):
        return _And([for (final arg in args) compileExpr(arg)]);
      case OrExpr(:final args):
        return _Or([for (final arg in args) compileExpr(arg)]);
      case EqualExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.eq);
      case NotEqualExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.neq);
      case GreaterExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.gt);
      case GreaterEqExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.gte);
      case LessExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.lt);
      case LessEqExpr(:final left, :final right):
        return _Compare(compileExpr(left), compileExpr(right), CompareOp.lte);
      case MatchExpr(:final left, :final right):
        return _Match(compileExpr(left), compileExpr(right), MatchKind.search);
      case NotMatchExpr(:final left, :final right):
        return _Match(compileExpr(left), compileExpr(right), MatchKind.search, not: true);
      case MatchesExpr(:final left, :final right):
        return _Match(compileExpr(left), compileExpr(right), MatchKind.prefix);
      case InExpr(:final left, :final right):
        return _In(compileExpr(left), compileExpr(right), not: false, compiler: this);
      case NotInExpr(:final left, :final right):
        return _In(compileExpr(left), compileExpr(right), not: true, compiler: this);
      case AddExpr(:final left, :final right):
        return _Arith(compileExpr(left), compileExpr(right), ArithOp.add);
      case SubExpr(:final left, :final right):
        return _Arith(compileExpr(left), compileExpr(right), ArithOp.sub);
      case MulExpr(:final left, :final right):
        return _Arith(compileExpr(left), compileExpr(right), ArithOp.mul);
      case DivExpr(:final left, :final right):
        return _Arith(compileExpr(left), compileExpr(right), ArithOp.div);
      case ModExpr(:final left, :final right):
        return _Arith(compileExpr(left), compileExpr(right), ArithOp.mod);
      case BetweenExpr(:final operand, :final lower, :final upper):
        return _Between(compileExpr(operand), compileExpr(lower), compileExpr(upper));
      case AnyExpr(:final left, :final op, :final right):
        return _Quantified(compileExpr(left), op, compileExpr(right), all: false, compiler: this);
      case AllExpr(:final left, :final op, :final right):
        return _Quantified(compileExpr(left), op, compileExpr(right), all: true, compiler: this);
    }
  }

  _Eval _compileFunction(String fname, List<Object> operands) {
    final name = fname.toLowerCase();
    if (name == 'meta' && operands.length == 1 && operands.single is Expr) {
      return _Subscript(_Column(table.columns['meta']!, name: 'meta'), _constText(operands.single as Expr));
    }
    if (name == 'entry_meta' && operands.length == 1 && operands.single is Expr) {
      return _EntryMeta(_constText(operands.single as Expr));
    }
    if (name == 'any_meta' && operands.length == 1 && operands.single is Expr) {
      return _AnyMeta(_constText(operands.single as Expr));
    }
    if (name == 'has_account' && operands.length == 1 && operands.single is Expr) {
      return _HasAccount(compileExpr(operands.single as Expr));
    }
    if (name == 'coalesce') {
      return _Coalesce([for (final operand in operands) compileExpr(operand as Expr)]);
    }
    final compiled = [
      for (final operand in operands)
        operand is Asterisk
            ? _Constant(const QueryValue.null_(), type: QueryType.asterisk)
            : compileExpr(operand as Expr),
    ];
    final spec = _lookupFunction(name, compiled.map((eval) => eval.type).toList());
    if (spec == null) {
      throw QueryException('no function matches "$name" name and argument types');
    }
    if (spec.aggregate) {
      return _Aggregate(spec, compiled, env);
    }
    return _Call(spec, compiled, env);
  }

  FuncSpec? _lookupFunction(String name, List<QueryType> args) {
    FuncSpec? fallback;
    for (final spec in functions) {
      if (spec.name != name) continue;
      if (spec.name == 'coalesce') return spec;
      if (spec.argTypes.length != args.length && spec.argTypes.length != 1) continue;
      if (spec.argTypes.length == 1 && spec.argTypes.single == QueryType.object) {
        fallback ??= spec;
        continue;
      }
      if (spec.argTypes.length != args.length) continue;
      var ok = true;
      for (var i = 0; i < args.length; i++) {
        if (!typeMatches(spec.argTypes[i], args[i])) {
          ok = false;
          break;
        }
      }
      if (ok) return spec;
    }
    return fallback;
  }

  String _constText(Expr expr) {
    final compiled = compileExpr(expr);
    final value = compiled.call(const Object());
    return value.asText() ?? '';
  }

  QueryValue _resolveParam(String? name) {
    final parameters = params;
    if (name == null) {
      if (parameters is List && parameters.isNotEmpty) {
        return queryValueFromLiteral(parameters.first);
      }
      throw QueryException('query parameter missing');
    }
    if (parameters is Map) {
      if (!parameters.containsKey(name)) {
        throw QueryException('query parameter missing: $name');
      }
      return queryValueFromLiteral(parameters[name]);
    }
    throw QueryException('query parameters should be a mapping when using named placeholders');
  }

  QueryResult _execute(_CompiledSelect query) {
    final rows = <List<QueryValue>>[];
    if (query.groupIndexes == null) {
      for (final row in query.table.rows()) {
        if (query.where != null && !isTruthy(query.where!.call(row))) continue;
        rows.add([for (final target in query.targets) target.eval.call(row)]);
      }
    } else {
      final aggregates = _collectAggregates(query.targets);
      final groups = <String, _Group>{};
      for (final row in query.table.rows()) {
        if (query.where != null && !isTruthy(query.where!.call(row))) continue;
        final keyValues = [for (final index in query.groupIndexes!) query.targets[index].eval.call(row)];
        final key = keyValues.map(_stringifyValue).join('\u0001');
        final group = groups.putIfAbsent(key, () => _Group(keyValues, aggregates.length));
        group.update(aggregates, row);
      }
      for (final group in groups.values) {
        final values = group.finalize(query.targets, aggregates);
        if (query.havingIndex != null && !isTruthy(values[query.havingIndex!])) continue;
        rows.add(values);
      }
    }

    var resultRows = rows;
    if (query.orderSpec != null) {
      resultRows.sort((a, b) {
        for (final (index, ordering) in query.orderSpec!) {
          final compared = compareValues(a[index], b[index]);
          if (compared != 0) {
            return ordering == Ordering.desc ? -compared : compared;
          }
        }
        return 0;
      });
    }
    final visible = [
      for (var i = 0; i < query.targets.length; i++)
        if (query.targets[i].name != null) i,
    ];
    var projected = [
      for (final row in resultRows) [for (final index in visible) row[index]],
    ];
    if (query.distinct) {
      final seen = <String>{};
      projected = [
        for (final row in projected)
          if (seen.add(row.map(_stringifyValue).join('\u0001'))) row,
      ];
    }
    if (query.limit != null && projected.length > query.limit!) {
      projected = projected.take(query.limit!).toList();
    }
    return QueryResult.table(
      columns: [
        for (final index in visible) QueryColumn(name: query.targets[index].name!, type: query.targets[index].type),
      ],
      rows: [for (final row in projected) QueryRow(row)],
    );
  }
}

class _Group {
  _Group(this.keys, int width) : stores = List<QueryValue?>.filled(width, null);

  final List<QueryValue> keys;
  final List<QueryValue?> stores;

  void update(List<_Aggregate> aggregates, Object row) {
    for (final aggregate in aggregates) {
      stores[aggregate.slot] = _aggregate(aggregate.spec.name, stores[aggregate.slot], aggregate.feed(row));
    }
  }

  List<QueryValue> finalize(List<_Target> targets, List<_Aggregate> aggregates) {
    for (final aggregate in aggregates) {
      aggregate.lookup = () => stores[aggregate.slot] ?? _emptyAgg(aggregate);
    }
    try {
      var keyIndex = 0;
      return [
        for (final target in targets)
          if (target.isAggregate) target.eval.call(const Object()) else keys[keyIndex++],
      ];
    } finally {
      for (final aggregate in aggregates) {
        aggregate.lookup = null;
      }
    }
  }
}

List<_Aggregate> _collectAggregates(List<_Target> targets) {
  final found = <_Aggregate>[];
  void walk(_Eval eval) {
    if (eval is _Aggregate) {
      eval.slot = found.length;
      found.add(eval);
    }
    for (final child in eval.children) {
      walk(child);
    }
  }

  for (final target in targets) {
    walk(target.eval);
  }
  return found;
}

QueryValue _emptyAgg(_Aggregate aggregate) {
  if (aggregate.spec.name == 'count') return const QueryValue.integer(0);
  if (aggregate.type == QueryType.inventory) return const QueryValue.inventory(Inventory());
  return const QueryValue.null_();
}

QueryValue _aggregate(String name, QueryValue? store, QueryValue next) {
  switch (name) {
    case 'count':
      final add = next is QueryInteger ? next.value : (next.isNull ? 0 : 1);
      return QueryValue.integer((store is QueryInteger ? store.value : 0) + add);
    case 'sum':
      if (next.isNull) return store ?? const QueryValue.null_();
      if (store == null || store.isNull) return next;
      return switch ((store, next)) {
        (QueryInteger(:final value), QueryInteger(value: final other)) => QueryValue.integer(value + other),
        (QueryNumber(:final value), QueryNumber(value: final other)) => QueryValue.number(value + other),
        (QueryInventory(:final value), QueryInventory(value: final other)) => QueryValue.inventory(
          value.addInventory(other),
        ),
        (QueryInventory(:final value), QueryAmount(value: final amount)) => QueryValue.inventory(
          value.addAmount(amount).inventory,
        ),
        (QueryInventory(:final value), QueryPosition(value: final position)) => QueryValue.inventory(
          value.addPosition(position).inventory,
        ),
        _ => store,
      };
    case 'min':
      if (next.isNull) return store ?? const QueryValue.null_();
      if (store == null || store.isNull) return next;
      return compareValues(next, store) < 0 ? next : store;
    case 'max':
      if (next.isNull) return store ?? const QueryValue.null_();
      if (store == null || store.isNull) return next;
      return compareValues(next, store) > 0 ? next : store;
    case 'first':
      return store ?? next;
    case 'last':
      return next;
    default:
      return next;
  }
}

QueryResult _pivot(QueryTable table, List<int> pivots) {
  if (pivots.length != 2) return table;
  final rowIndex = pivots[0];
  final colIndex = pivots[1];
  final valueIndexes = [
    for (var i = 0; i < table.columns.length; i++)
      if (i != rowIndex && i != colIndex) i,
  ];
  final colKeys = <String>{};
  for (final row in table.rows) {
    colKeys.add(_stringifyValue(row.values[colIndex]));
  }
  final sortedKeys = colKeys.toList()..sort();
  final names = <QueryColumn>[
    QueryColumn(
      name: '${table.columns[rowIndex].name}/${table.columns[colIndex].name}',
      type: table.columns[rowIndex].type,
    ),
  ];
  if (valueIndexes.length <= 1) {
    for (final key in sortedKeys) {
      names.add(
        QueryColumn(name: key, type: valueIndexes.isEmpty ? QueryType.object : table.columns[valueIndexes.single].type),
      );
    }
  } else {
    for (final key in sortedKeys) {
      for (final index in valueIndexes) {
        names.add(QueryColumn(name: '$key/${table.columns[index].name}', type: table.columns[index].type));
      }
    }
  }
  final grouped = <String, Map<String, QueryRow>>{};
  for (final row in table.rows) {
    final rowKey = _stringifyValue(row.values[rowIndex]);
    final colKey = _stringifyValue(row.values[colIndex]);
    grouped.putIfAbsent(rowKey, () => {})[colKey] = row;
  }
  final out = <QueryRow>[];
  final rowKeys = grouped.keys.toList()..sort();
  for (final rowKey in rowKeys) {
    final cells = grouped[rowKey]!;
    final sample = cells.values.first;
    final values = <QueryValue>[sample.values[rowIndex]];
    for (final colKey in sortedKeys) {
      final match = cells[colKey];
      if (valueIndexes.length <= 1) {
        values.add(
          match == null || valueIndexes.isEmpty ? const QueryValue.null_() : match.values[valueIndexes.single],
        );
      } else {
        for (final index in valueIndexes) {
          values.add(match == null ? const QueryValue.null_() : match.values[index]);
        }
      }
    }
    out.add(QueryRow(values));
  }
  return QueryResult.table(columns: names, rows: out) as QueryTable;
}

class _ResultTable extends BqlTable {
  _ResultTable(this.result);
  final QueryTable result;

  @override
  String get name => 'subquery';

  @override
  late final Map<String, ColumnSpec> columns = {
    for (var i = 0; i < result.columns.length; i++)
      result.columns[i].name: ColumnSpec(result.columns[i].type, (row) => (row as QueryRow).values[i]),
  };

  @override
  Iterable<Object> rows() => result.rows;
}

class _Column extends _Eval {
  _Column(this.spec, {this.name});
  final ColumnSpec spec;
  final String? name;
  @override
  QueryType get type => spec.type;
  @override
  QueryValue call(Object row) => spec.read(row);
}

// Running `balance` is partitioned by GROUP BY keys that are not date parts, so monthly last(balance) still carries an account forward.
class _BalanceWindow {
  List<_Eval> partition = const [];
  final Map<String, Inventory> _running = {};
  Object? _row;
  QueryValue? _value;

  QueryValue of(Object row) {
    if (identical(row, _row) && _value != null) return _value!;
    final position = _positionOf(row);
    final key = [for (final eval in partition) _stringifyValue(eval.call(row))].join('\u0001');
    final next = (_running[key] ?? const Inventory()).addPosition(position).inventory;
    _running[key] = next;
    _row = row;
    _value = QueryValue.inventory(next);
    return _value!;
  }
}

Position _positionOf(Object row) {
  if (row is PostingRow) {
    return Position(units: row.posting.units, cost: row.posting.cost);
  }
  throw QueryException('balance is only defined on postings');
}

bool _isDateDerived(_Eval eval) {
  const dateColumns = {'date', 'year', 'month', 'day'};
  const dateFunctions = {'year', 'month', 'day', 'yearmonth', 'quarter', 'weekday', 'date_trunc', 'date_part'};
  if (eval is _Column) return dateColumns.contains(eval.name);
  if (eval is _Call) {
    if (dateFunctions.contains(eval.spec.name)) return true;
    return eval.args.isNotEmpty && eval.args.every(_isDateDerived);
  }
  if (eval is _Attribute) {
    return dateColumns.contains(eval.name) || _isDateDerived(eval.operand);
  }
  if (eval is _Constant) return true;
  final children = eval.children;
  return children.isNotEmpty && children.every(_isDateDerived);
}

class _Balance extends _Eval {
  _Balance(this.window);
  final _BalanceWindow window;
  @override
  QueryType get type => QueryType.inventory;
  @override
  QueryValue call(Object row) => window.of(row);
}

class _Constant extends _Eval {
  _Constant(this.value, {QueryType? type}) : type = type ?? value.type;
  final QueryValue value;
  @override
  final QueryType type;
  @override
  QueryValue call(Object row) => value;
}

class _Call extends _Eval {
  _Call(this.spec, this.args, this.env);
  final FuncSpec spec;
  final List<_Eval> args;
  final TableEnv env;
  @override
  QueryType get type => spec.outType;
  @override
  bool get isAggregate => args.any((arg) => arg.isAggregate);
  @override
  List<_Eval> get children => args;
  @override
  QueryValue call(Object row) {
    final values = [for (final arg in args) arg.call(row)];
    if (spec.name != 'coalesce' && values.any((value) => value.isNull) && spec.outType != QueryType.boolean) {
      if (spec.name != 'bool' &&
          spec.name != 'int' &&
          spec.name != 'decimal' &&
          spec.name != 'str' &&
          spec.name != 'date') {
        return const QueryValue.null_();
      }
    }
    return spec.eval(row, env, values);
  }
}

class _Aggregate extends _Eval {
  _Aggregate(this.spec, this.args, this.env);
  final FuncSpec spec;
  final List<_Eval> args;
  final TableEnv env;
  int slot = 0;
  QueryValue Function()? lookup;
  @override
  QueryType get type => spec.outType;
  @override
  bool get isAggregate => true;
  @override
  List<_Eval> get children => args;
  QueryValue feed(Object row) {
    final values = [for (final arg in args) arg.call(row)];
    return spec.eval(row, env, values);
  }

  @override
  QueryValue call(Object row) {
    final resolved = lookup;
    if (resolved != null) return resolved();
    return feed(row);
  }
}

class _And extends _Eval {
  _And(this.args);
  final List<_Eval> args;
  @override
  QueryType get type => QueryType.boolean;
  @override
  bool get isAggregate => args.any((arg) => arg.isAggregate);
  @override
  List<_Eval> get children => args;
  @override
  QueryValue call(Object row) {
    for (final arg in args) {
      if (!isTruthy(arg.call(row))) return const QueryValue.boolean(false);
    }
    return const QueryValue.boolean(true);
  }
}

class _Or extends _Eval {
  _Or(this.args);
  final List<_Eval> args;
  @override
  QueryType get type => QueryType.boolean;
  @override
  bool get isAggregate => args.any((arg) => arg.isAggregate);
  @override
  List<_Eval> get children => args;
  @override
  QueryValue call(Object row) {
    for (final arg in args) {
      if (isTruthy(arg.call(row))) return const QueryValue.boolean(true);
    }
    return const QueryValue.boolean(false);
  }
}

class _Not extends _Eval {
  _Not(this.operand);
  final _Eval operand;
  @override
  QueryType get type => QueryType.boolean;
  @override
  bool get isAggregate => operand.isAggregate;
  @override
  List<_Eval> get children => [operand];
  @override
  QueryValue call(Object row) => QueryValue.boolean(!isTruthy(operand.call(row)));
}

class _IsNull extends _Eval {
  _IsNull(this.operand, {required this.not});
  final _Eval operand;
  final bool not;
  @override
  QueryType get type => QueryType.boolean;
  @override
  bool get isAggregate => operand.isAggregate;
  @override
  List<_Eval> get children => [operand];
  @override
  QueryValue call(Object row) {
    final isNull = operand.call(row).isNull;
    return QueryValue.boolean(not ? !isNull : isNull);
  }
}

enum CompareOp { eq, neq, gt, gte, lt, lte }

class _Compare extends _Eval {
  _Compare(this.left, this.right, this.op);
  final _Eval left;
  final _Eval right;
  final CompareOp op;
  @override
  QueryType get type => QueryType.boolean;
  @override
  bool get isAggregate => left.isAggregate || right.isAggregate;
  @override
  List<_Eval> get children => [left, right];
  @override
  QueryValue call(Object row) {
    final a = left.call(row);
    final b = right.call(row);
    final equal = valuesEqual(a, b);
    final compared = compareValues(a, b);
    return QueryValue.boolean(switch (op) {
      CompareOp.eq => equal,
      CompareOp.neq => !equal,
      CompareOp.gt => compared > 0,
      CompareOp.gte => compared >= 0,
      CompareOp.lt => compared < 0,
      CompareOp.lte => compared <= 0,
    });
  }
}

enum MatchKind { search, prefix }

class _Match extends _Eval {
  _Match(this.left, this.right, this.kind, {this.not = false});
  final _Eval left;
  final _Eval right;
  final MatchKind kind;
  final bool not;
  @override
  QueryType get type => QueryType.boolean;
  @override
  QueryValue call(Object row) {
    final text = left.call(row).asText() ?? '';
    final pattern = right.call(row).asText() ?? '';
    final regex = RegExp(pattern);
    final matched = kind == MatchKind.search ? regex.hasMatch(text) : regex.matchAsPrefix(text) != null;
    return QueryValue.boolean(not ? !matched : matched);
  }
}

class _In extends _Eval {
  _In(this.left, this.right, {required this.not, required this.compiler});
  final _Eval left;
  final _Eval right;
  final bool not;
  final _Compiler compiler;
  @override
  QueryType get type => QueryType.boolean;
  @override
  QueryValue call(Object row) {
    var rhs = right;
    if (rhs is _Subquery) {
      rhs = _Constant(QueryValue.list(rhs.values()));
    }
    final needle = left.call(row);
    final haystack = membershipStrings(rhs.call(row));
    final contained = haystack.contains(needle.asText() ?? _stringifyValue(needle));
    return QueryValue.boolean(not ? !contained : contained);
  }
}

class _Quantified extends _Eval {
  _Quantified(this.left, this.op, this.right, {required this.all, required this.compiler});
  final _Eval left;
  final String op;
  final _Eval right;
  final bool all;
  final _Compiler compiler;
  @override
  QueryType get type => QueryType.boolean;
  @override
  QueryValue call(Object row) {
    final needle = left.call(row);
    var rhs = right.call(row);
    if (right is _Subquery) {
      rhs = QueryValue.list((right as _Subquery).values());
    }
    final items = membershipStrings(rhs);
    bool test(String item) {
      final text = needle.asText() ?? _stringifyValue(needle);
      return switch (op) {
        '=' => text == item,
        '!=' => text != item,
        '~' => RegExp(item).hasMatch(text) || RegExp(text).hasMatch(item),
        '?~' => RegExp(item).matchAsPrefix(text) != null || RegExp(text).matchAsPrefix(item) != null,
        _ => text == item,
      };
    }

    final matched = all ? items.every(test) : items.any(test);
    return QueryValue.boolean(items.isEmpty ? all : matched);
  }
}

class _Arith extends _Eval {
  _Arith(this.left, this.right, this.op);
  final _Eval left;
  final _Eval right;
  final ArithOp op;
  @override
  QueryType get type =>
      left.type == QueryType.number || right.type == QueryType.number ? QueryType.number : QueryType.integer;
  @override
  bool get isAggregate => left.isAggregate || right.isAggregate;
  @override
  List<_Eval> get children => [left, right];
  @override
  QueryValue call(Object row) {
    final a = left.call(row);
    final b = right.call(row);
    if (a.isNull || b.isNull) return const QueryValue.null_();
    if (a is QueryText || b is QueryText) {
      if (op == ArithOp.add) {
        return QueryValue.text('${a.asText() ?? ''}${b.asText() ?? ''}');
      }
    }
    final leftNum = _number(a);
    final rightNum = _number(b);
    if (leftNum == null || rightNum == null) return const QueryValue.null_();
    return switch (op) {
      ArithOp.add => _numValue(a, b, leftNum + rightNum),
      ArithOp.sub => _numValue(a, b, leftNum - rightNum),
      ArithOp.mul => _numValue(a, b, leftNum * rightNum),
      ArithOp.div => _numValue(a, b, (leftNum / rightNum).toDecimal(scaleOnInfinitePrecision: 28)),
      ArithOp.mod => QueryValue.integer(leftNum.toBigInt().toInt() % rightNum.toBigInt().toInt()),
    };
  }
}

enum ArithOp { add, sub, mul, div, mod }

QueryValue _numValue(QueryValue a, QueryValue b, Decimal value) {
  if (a is QueryInteger && b is QueryInteger && value == Decimal.fromInt(value.toBigInt().toInt())) {
    return QueryValue.integer(value.toBigInt().toInt());
  }
  return QueryValue.number(value);
}

Decimal? _number(QueryValue value) => switch (value) {
  QueryInteger(:final value) => Decimal.fromInt(value),
  QueryNumber(:final value) => value,
  QueryBoolean(:final value) => Decimal.fromInt(value ? 1 : 0),
  _ => null,
};

class _Between extends _Eval {
  _Between(this.operand, this.lower, this.upper);
  final _Eval operand;
  final _Eval lower;
  final _Eval upper;
  @override
  QueryType get type => QueryType.boolean;
  @override
  QueryValue call(Object row) {
    final value = operand.call(row);
    return QueryValue.boolean(compareValues(value, lower.call(row)) >= 0 && compareValues(value, upper.call(row)) <= 0);
  }
}

class _Attribute extends _Eval {
  _Attribute(this.operand, this.name);
  final _Eval operand;
  final String name;
  @override
  QueryType get type => QueryType.object;
  @override
  QueryValue call(Object row) {
    final value = operand.call(row);
    return switch ((value, name)) {
      (QueryDate(:final value), 'year') => QueryValue.integer(value.year),
      (QueryDate(:final value), 'month') => QueryValue.integer(value.month),
      (QueryDate(:final value), 'day') => QueryValue.integer(value.day),
      (QueryAmount(:final value), 'number') => QueryValue.number(value.number),
      (QueryAmount(:final value), 'currency') => QueryValue.text(value.currency.name),
      (QueryPosition(:final value), 'units') => QueryValue.amount(value.units),
      (QueryPosition(:final value), 'cost') =>
        value.cost == null ? const QueryValue.null_() : QueryValue.cost(value.cost!),
      (QueryCost(:final value), 'number') => QueryValue.number(value.number),
      (QueryCost(:final value), 'currency') => QueryValue.text(value.currency.name),
      (QueryCost(:final value), 'date') => QueryValue.date(value.date),
      (QueryCost(:final value), 'label') => QueryValue.text(value.label ?? ''),
      (QueryTransaction(), 'meta') => QueryValue.meta(const Meta()),
      (QueryDirective(:final value), 'date') => QueryValue.date(value.date),
      (QueryDirective(:final value), 'meta') => QueryValue.meta(value.meta),
      _ => const QueryValue.null_(),
    };
  }
}

class _Subscript extends _Eval {
  _Subscript(this.operand, this.key);
  final _Eval operand;
  final String key;
  @override
  QueryType get type => QueryType.object;
  @override
  QueryValue call(Object row) {
    final value = operand.call(row);
    if (value is QueryMeta) return metaLookup(value.value, key);
    return const QueryValue.null_();
  }
}

class _EntryMeta extends _Eval {
  _EntryMeta(this.key);
  final String key;
  @override
  QueryType get type => QueryType.object;
  @override
  QueryValue call(Object row) {
    if (row is PostingRow) return metaLookup(row.directive.meta, key);
    if (row is Directive) return metaLookup(row.meta, key);
    return const QueryValue.null_();
  }
}

class _AnyMeta extends _Eval {
  _AnyMeta(this.key);
  final String key;
  @override
  QueryType get type => QueryType.object;
  @override
  QueryValue call(Object row) {
    if (row is PostingRow) {
      final posting = metaLookup(row.posting.meta, key);
      if (!posting.isNull) return posting;
      return metaLookup(row.directive.meta, key);
    }
    return const QueryValue.null_();
  }
}

class _HasAccount extends _Eval {
  _HasAccount(this.pattern);
  final _Eval pattern;
  @override
  QueryType get type => QueryType.boolean;
  @override
  QueryValue call(Object row) {
    final regex = RegExp('(?i)${pattern.call(row).asText() ?? ''}');
    final accounts = switch (row) {
      PostingRow(:final transaction) => [for (final posting in transaction.postings) posting.account.name],
      Directive(:final body) => [for (final account in _directiveAccounts(body)) account.name],
      _ => const <String>[],
    };
    return QueryValue.boolean(accounts.any(regex.hasMatch));
  }
}

Set<Account> _directiveAccounts(DirectiveBody body) => switch (body) {
  TransactionBody(:final value) => {for (final posting in value.postings) posting.account},
  OpenBody(:final account) => {account},
  CloseBody(:final account) => {account},
  BalanceBody(:final account) => {account},
  _ => {},
};

class _Coalesce extends _Eval {
  _Coalesce(this.args);
  final List<_Eval> args;
  @override
  QueryType get type => args.first.type;
  @override
  QueryValue call(Object row) {
    for (final arg in args) {
      final value = arg.call(row);
      if (!value.isNull) return value;
    }
    return const QueryValue.null_();
  }
}

class _Subquery extends _Eval {
  _Subquery(this.compiler, this.select);
  final _Compiler compiler;
  final SelectStatement select;
  @override
  QueryType get type => QueryType.set;
  List<QueryValue> values() {
    final compiled = compiler._compileSelect(select);
    final result = compiler._execute(compiled);
    if (result is! QueryTable) return const [];
    return [
      for (final row in result.rows)
        if (row.values.isNotEmpty) row.values.first,
    ];
  }

  @override
  QueryValue call(Object row) => QueryValue.list(values());
}

SelectStatement _desugarBalances(BalancesStatement statement) {
  final summary = statement.summaryFunc;
  final position = summary == null || summary.isEmpty
      ? const Expr.column('position')
      : Expr.function(summary, [const Expr.column('position')]);
  return SelectStatement(
    targets: [
      const Target(expression: Expr.column('account')),
      Target(expression: Expr.function('sum', [position])),
    ],
    fromClause: statement.fromClause,
    whereClause: statement.whereClause,
    groupBy: const GroupBy(
      columns: [
        Expr.column('account'),
        Expr.function('account_sortkey', [Expr.column('account')]),
      ],
    ),
    orderBy: const [
      OrderBy(column: Expr.function('account_sortkey', [Expr.column('account')])),
    ],
  );
}

SelectStatement _desugarJournal(JournalStatement statement) {
  final summary = statement.summaryFunc;
  Expr wrap(Expr inner) => summary == null || summary.isEmpty ? inner : Expr.function(summary, [inner]);
  return SelectStatement(
    targets: [
      const Target(expression: Expr.column('date')),
      const Target(expression: Expr.column('flag')),
      const Target(expression: Expr.function('maxwidth', [Expr.column('payee'), Expr.constant(48)])),
      const Target(expression: Expr.function('maxwidth', [Expr.column('narration'), Expr.constant(80)])),
      const Target(expression: Expr.column('account')),
      Target(expression: wrap(const Expr.column('position'))),
      Target(expression: wrap(const Expr.column('balance'))),
    ],
    fromClause: statement.fromClause,
    whereClause: statement.account == null
        ? null
        : Expr.match(const Expr.column('account'), Expr.constant(statement.account)),
  );
}

String _exprLabel(Expr expr) => switch (expr) {
  ColumnExpr(:final name) => name,
  FunctionExpr(:final fname, :final operands) =>
    '$fname(${operands.map((operand) => operand is Expr ? _exprLabel(operand) : '*').join(', ')})',
  ConstantExpr(:final value) => '$value',
  _ => 'column',
};

int compareValues(QueryValue left, QueryValue right) {
  if (left.isNull && right.isNull) return 0;
  if (left.isNull) return -1;
  if (right.isNull) return 1;
  final a = left is QueryMetaCell ? _unwrapMeta(left.value) : left;
  final b = right is QueryMetaCell ? _unwrapMeta(right.value) : right;
  if (a is QueryInteger && b is QueryInteger) return a.value.compareTo(b.value);
  if (a is QueryNumber && b is QueryNumber) return a.value.compareTo(b.value);
  if (a is QueryInteger && b is QueryNumber) return Decimal.fromInt(a.value).compareTo(b.value);
  if (a is QueryNumber && b is QueryInteger) return a.value.compareTo(Decimal.fromInt(b.value));
  if (a is QueryDate && b is QueryDate) return compareBeanDate(a.value, b.value);
  if (a is QueryBoolean && b is QueryBoolean) return a.value == b.value ? 0 : (a.value ? 1 : -1);
  final leftText = a.asText() ?? _stringifyValue(a);
  final rightText = b.asText() ?? _stringifyValue(b);
  return leftText.compareTo(rightText);
}

bool valuesEqual(QueryValue left, QueryValue right) {
  if (left.isNull && right.isNull) return true;
  if (left.isNull || right.isNull) return false;
  if (left == right) return true;
  final aText = left.asText();
  final bText = right.asText();
  if (aText != null && bText != null) return aText == bText;
  return compareValues(left, right) == 0;
}

QueryValue _unwrapMeta(MetaValue value) => switch (value) {
  MetaText(:final value) => QueryValue.text(value),
  MetaAccount(:final value) => QueryValue.account(value),
  MetaCurrency(:final value) => QueryValue.currency(value),
  MetaTag(:final value) => QueryValue.text(value.name),
  MetaDate(:final value) => QueryValue.date(value),
  MetaBoolean(:final value) => QueryValue.boolean(value),
  MetaNumber(:final value) => QueryValue.number(value),
  MetaAmount(:final value) => QueryValue.amount(value),
};

String _stringifyValue(QueryValue value) => switch (value) {
  QueryNull() => '',
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
  QueryMetaCell(:final value) => _stringifyValue(_unwrapMeta(value)),
  _ => value.toString(),
};
