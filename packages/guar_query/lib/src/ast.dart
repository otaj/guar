// Freezed AST for beanquery BQL statements and expressions.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guar_domain/guar_domain.dart';

part 'ast.freezed.dart';

enum Ordering { asc, desc }

@freezed
sealed class Statement with _$Statement {
  const factory Statement.select({
    required Object targets,
    FromClause? fromClause,
    Expr? whereClause,
    GroupBy? groupBy,
    List<OrderBy>? orderBy,
    PivotBy? pivotBy,
    int? limit,
    bool? distinct,
  }) = SelectStatement;

  const factory Statement.balances({String? summaryFunc, FromClause? fromClause, Expr? whereClause}) =
      BalancesStatement;

  const factory Statement.journal({String? account, String? summaryFunc, FromClause? fromClause}) = JournalStatement;

  const factory Statement.print({FromClause? fromClause}) = PrintStatement;

  const factory Statement.createTable({
    required String name,
    List<(String name, String type)>? columns,
    String? using,
    SelectStatement? query,
  }) = CreateTableStatement;

  const factory Statement.insert({required TableRef table, required List<Expr> values, List<Expr>? columns}) =
      InsertStatement;
}

@freezed
abstract class TableRef with _$TableRef {
  const factory TableRef(String name) = _TableRef;
}

@freezed
sealed class FromClause with _$FromClause {
  const factory FromClause.table(String name) = TableFrom;

  const factory FromClause.subselect(SelectStatement select) = SubselectFrom;

  const factory FromClause.filter({Expr? expression, BeanDate? open, CloseSpec? close, bool? clear}) = FilterFrom;
}

@freezed
sealed class CloseSpec with _$CloseSpec {
  const factory CloseSpec.end() = CloseEnd;
  const factory CloseSpec.on(BeanDate date) = CloseOnDate;
}

@freezed
abstract class Target with _$Target {
  const factory Target({required Expr expression, String? name}) = _Target;
}

@freezed
abstract class Asterisk with _$Asterisk {
  const factory Asterisk() = _Asterisk;
}

@freezed
abstract class GroupBy with _$GroupBy {
  const factory GroupBy({required List<Object> columns, Expr? having}) = _GroupBy;
}

@freezed
abstract class OrderBy with _$OrderBy {
  const factory OrderBy({required Object column, @Default(Ordering.asc) Ordering ordering}) = _OrderBy;
}

@freezed
abstract class PivotBy with _$PivotBy {
  const factory PivotBy({required List<Object> columns}) = _PivotBy;
}

@freezed
sealed class Expr with _$Expr {
  const factory Expr.column(String name) = ColumnExpr;
  const factory Expr.constant(Object? value) = ConstantExpr;
  const factory Expr.placeholder(String? name) = PlaceholderExpr;
  const factory Expr.function(String fname, List<Object> operands) = FunctionExpr;
  const factory Expr.attribute(Expr operand, String name) = AttributeExpr;
  const factory Expr.subscript(Expr operand, String key) = SubscriptExpr;
  const factory Expr.asterisk() = AsteriskExpr;
  const factory Expr.select(SelectStatement select) = SelectExpr;

  const factory Expr.not(Expr operand) = NotExpr;
  const factory Expr.isNull(Expr operand) = IsNullExpr;
  const factory Expr.isNotNull(Expr operand) = IsNotNullExpr;
  const factory Expr.neg(Expr operand) = NegExpr;

  const factory Expr.and(List<Expr> args) = AndExpr;
  const factory Expr.or(List<Expr> args) = OrExpr;

  const factory Expr.eq(Expr left, Expr right) = EqualExpr;
  const factory Expr.neq(Expr left, Expr right) = NotEqualExpr;
  const factory Expr.gt(Expr left, Expr right) = GreaterExpr;
  const factory Expr.gte(Expr left, Expr right) = GreaterEqExpr;
  const factory Expr.lt(Expr left, Expr right) = LessExpr;
  const factory Expr.lte(Expr left, Expr right) = LessEqExpr;
  const factory Expr.match(Expr left, Expr right) = MatchExpr;
  const factory Expr.notMatch(Expr left, Expr right) = NotMatchExpr;
  const factory Expr.matches(Expr left, Expr right) = MatchesExpr;
  const factory Expr.in_(Expr left, Expr right) = InExpr;
  const factory Expr.notIn(Expr left, Expr right) = NotInExpr;
  const factory Expr.add(Expr left, Expr right) = AddExpr;
  const factory Expr.sub(Expr left, Expr right) = SubExpr;
  const factory Expr.mul(Expr left, Expr right) = MulExpr;
  const factory Expr.div(Expr left, Expr right) = DivExpr;
  const factory Expr.mod(Expr left, Expr right) = ModExpr;

  const factory Expr.between({required Expr operand, required Expr lower, required Expr upper}) = BetweenExpr;
  const factory Expr.any({required Expr left, required String op, required Expr right}) = AnyExpr;
  const factory Expr.all({required Expr left, required String op, required Expr right}) = AllExpr;
}

bool literalEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Decimal && b is Decimal) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!literalEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
