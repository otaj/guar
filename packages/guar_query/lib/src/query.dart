// Public Query entry point: parse, compile, and execute BQL.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_query/src/ast.dart';
import 'package:guar_query/src/compile.dart';
import 'package:guar_query/src/grammar.dart';
import 'package:guar_query/src/result.dart';

class Query {
  Query({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final DateTime Function() clock;

  Statement parse(String source) => parseBql(source);

  QueryResult execute(Ledger ledger, Statement statement, {Object? params}) {
    try {
      return compileAndExecute(statement, ledger, params: params, clock: clock);
    } on QueryException catch (error) {
      return QueryResult.errors(<QueryError>[error.toError()]);
    }
  }

  QueryResult run(Ledger ledger, String source, {Object? params}) {
    try {
      return execute(ledger, parse(source), params: params);
    } on QueryException catch (error) {
      return QueryResult.errors(<QueryError>[error.toError()]);
    }
  }
}
