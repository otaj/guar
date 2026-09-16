// XOR query result: a table, printed directives, or errors.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guar_domain/guar_domain.dart';

import 'value.dart';

part 'result.freezed.dart';

@freezed
abstract class QueryColumn with _$QueryColumn {
  const factory QueryColumn({required String name, required QueryType type}) = _QueryColumn;
}

@freezed
abstract class QueryRow with _$QueryRow {
  const factory QueryRow(List<QueryValue> values) = _QueryRow;
}

@freezed
abstract class QueryError with _$QueryError {
  const factory QueryError({required String message, BeanLocation? location}) = _QueryError;
}

@freezed
sealed class QueryResult with _$QueryResult {
  const factory QueryResult.table({required List<QueryColumn> columns, required List<QueryRow> rows}) = QueryTable;

  const factory QueryResult.entries(List<Directive> directives) = QueryEntries;

  const factory QueryResult.errors(List<QueryError> errors) = QueryErrors;
}

class QueryException implements Exception {
  QueryException(this.message, {this.location});

  final String message;
  final BeanLocation? location;

  QueryError toError() => QueryError(message: message, location: location);

  @override
  String toString() => message;
}
