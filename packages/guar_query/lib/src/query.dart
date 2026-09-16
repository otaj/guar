// Public Query entry point: parse, compile, and execute BQL.

import 'package:guar_domain/guar_domain.dart';

import 'ast.dart';
import 'compile.dart';
import 'grammar.dart';
import 'result.dart';

class Query {
  Query({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final DateTime Function() clock;

  Statement parse(String source) => parseBql(source);

  QueryResult execute(Ledger ledger, Statement statement, {Object? params}) {
    try {
      return compileAndExecute(statement, ledger, params: params, clock: clock);
    } on QueryException catch (error) {
      return QueryResult.errors([error.toError()]);
    }
  }

  QueryResult run(Ledger ledger, String source, {Object? params}) {
    try {
      return execute(ledger, parse(source), params: params);
    } on QueryException catch (error) {
      return QueryResult.errors([error.toError()]);
    }
  }
}
