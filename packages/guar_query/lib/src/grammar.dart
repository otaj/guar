// Petitparser grammar for beanquery BQL.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:petitparser/petitparser.dart';

import 'ast.dart';
import 'result.dart';

const _keywords = {
  'and',
  'as',
  'asc',
  'by',
  'create',
  'desc',
  'distinct',
  'false',
  'from',
  'group',
  'having',
  'in',
  'insert',
  'into',
  'is',
  'limit',
  'not',
  'or',
  'order',
  'pivot',
  'select',
  'table',
  'true',
  'using',
  'where',
  'balances',
  'journal',
  'print',
};

class BqlGrammar extends GrammarDefinition<Statement> {
  const BqlGrammar();

  @override
  Parser<Statement> start() => ref0(bql);

  Parser<Statement> statement() =>
      (ref0(select) | ref0(balances) | ref0(journal) | ref0(printStmt) | ref0(createTable) | ref0(insert))
          .cast<Statement>();

  Parser<Statement> bql() => (ref0(space) & ref0(statement) & token(char(';')).optional() & ref0(space) & endOfInput())
      .pick(1)
      .cast<Statement>();

  Parser<void> space() => (whitespace() | blockComment() | lineComment()).star().map((_) {});

  Parser<void> blockComment() => (string('/*') & (string('*/').not() & any()).star() & string('*/')).map((_) {});

  Parser<void> lineComment() => (char(';') & noneOf('\n').star()).map((_) {});

  Parser<T> token<T>(Parser<T> inner) => (space() & inner & space()).pick(1).cast<T>();

  Parser<void> kw(String word) => token((string(word, ignoreCase: true) & pattern('a-zA-Z0-9_').not()).map((_) {}));

  Parser<SelectStatement> select() {
    final distinct = (kw('DISTINCT') & epsilon().map((_) => true)).pick(1);
    final targets = (asterisk().map<Object>((_) => const Asterisk()) | targetList()).cast<Object>();
    return (kw('SELECT') &
            distinct.optional() &
            targets &
            ref0(fromPart).optional() &
            ref0(wherePart).optional() &
            ref0(groupPart).optional() &
            ref0(orderPart).optional() &
            ref0(pivotPart).optional() &
            ref0(limitPart).optional())
        .map((values) {
          return SelectStatement(
            targets: values[2] as Object,
            distinct: values[1] as bool?,
            fromClause: values[3] as FromClause?,
            whereClause: values[4] as Expr?,
            groupBy: values[5] as GroupBy?,
            orderBy: values[6] as List<OrderBy>?,
            pivotBy: values[7] as PivotBy?,
            limit: values[8] as int?,
          );
        });
  }

  Parser<List<Target>> targetList() => (ref0(target) & (token(char(',')) & ref0(target)).star()).map((values) {
    final first = values[0] as Target;
    final rest = [for (final pair in values[1] as List<dynamic>) (pair as List<dynamic>)[1] as Target];
    return [first, ...rest];
  });

  Parser<Target> target() => (ref0(expression) & (kw('AS') & ref0(identifier)).optional()).map((values) {
    final asClause = values[1] as List<dynamic>?;
    return Target(expression: values[0] as Expr, name: asClause == null ? null : asClause[1] as String);
  });

  Parser<Asterisk> asterisk() => token(char('*')).map((_) => const Asterisk());

  Parser<FromClause> fromPart() => (kw('FROM') & ref0(fromSource)).pick(1).cast<FromClause>();

  Parser<FromClause> fromSource() =>
      (ref0(subselectFrom) | ref0(hashTable) | ref0(quotedTable) | ref0(fromFilter)).cast<FromClause>();

  Parser<FromClause> quotedTable() => token(quotedIdentifier()).map(FromClause.table);

  Parser<FromClause> subselectFrom() => (token(char('(')) & ref0(select) & token(char(')')))
      .pick(1)
      .map((select) => FromClause.subselect(select as SelectStatement));

  Parser<FromClause> hashTable() => token(
    (char('#') & (pattern('a-zA-Z_') & pattern('a-zA-Z0-9_').star()).flatten().optional()).map((values) {
      final name = values[1] as String?;
      return FromClause.table(name?.toLowerCase() ?? '');
    }),
  );

  Parser<FromClause> fromFilter() {
    final openOn = (kw('OPEN') & kw('ON') & dateLit()).map((values) => values[2] as BeanDate);
    final closeOn =
        (kw('CLOSE') &
                ((kw('ON') & dateLit()).map((values) => CloseSpec.on(values[1] as BeanDate)) |
                    epsilon().map((_) => const CloseSpec.end())))
            .pick(1)
            .cast<CloseSpec>();
    final clear = kw('CLEAR').map((_) => true);

    final openOnly = (openOn & closeOn.optional() & clear.optional()).map((values) {
      return FromClause.filter(open: values[0] as BeanDate, close: values[1] as CloseSpec?, clear: values[2] as bool?);
    });
    final closeOnly = (closeOn & clear.optional()).map((values) {
      return FromClause.filter(close: values[0] as CloseSpec, clear: values[1] as bool?);
    });
    final clearOnly = clear.map((_) => const FromClause.filter(clear: true));
    final exprForm = (ref0(expression) & openOn.optional() & closeOn.optional() & clear.optional()).map((values) {
      return FromClause.filter(
        expression: values[0] as Expr,
        open: values[1] as BeanDate?,
        close: values[2] as CloseSpec?,
        clear: values[3] as bool?,
      );
    });
    return (openOnly | closeOnly | clearOnly | exprForm).cast<FromClause>();
  }

  Parser<Expr> wherePart() => (kw('WHERE') & ref0(expression)).pick(1).cast<Expr>();

  Parser<GroupBy> groupPart() =>
      (kw('GROUP') & kw('BY') & ref0(groupColumns) & (kw('HAVING') & ref0(expression)).optional()).map((values) {
        final having = values[3] as List<dynamic>?;
        return GroupBy(columns: values[2] as List<Object>, having: having == null ? null : having[1] as Expr);
      });

  Parser<List<Object>> groupColumns() =>
      commaSeparated(integerLit().map<Object>((v) => v).or(ref0(expression)).cast<Object>());

  Parser<List<OrderBy>> orderPart() =>
      (kw('ORDER') & kw('BY') & commaSeparated(orderItem())).pick(2).cast<List<OrderBy>>();

  Parser<OrderBy> orderItem() =>
      ((integerLit().map<Object>((v) => v) | ref0(expression)).cast<Object>() & ref0(ordering)).map((values) {
        return OrderBy(column: values[0] as Object, ordering: values[1] as Ordering);
      });

  Parser<Ordering> ordering() =>
      (kw('DESC').map((_) => Ordering.desc) | kw('ASC').map((_) => Ordering.asc) | epsilon().map((_) => Ordering.asc))
          .cast<Ordering>();

  Parser<PivotBy> pivotPart() =>
      (kw('PIVOT') & kw('BY') & pivotColumn() & token(char(',')) & pivotColumn()).map((values) {
        return PivotBy(columns: [values[2] as Object, values[4] as Object]);
      });

  Parser<Object> pivotColumn() => (integerLit().map<Object>((v) => v) | column()).cast<Object>();

  Parser<int> limitPart() => (kw('LIMIT') & integerLit()).pick(1).cast<int>();

  Parser<BalancesStatement> balances() =>
      (kw('BALANCES') &
              (kw('AT') & ref0(identifier)).optional() &
              ref0(fromPart).optional() &
              ref0(wherePart).optional())
          .map((values) {
            final at = values[1] as List<dynamic>?;
            return BalancesStatement(
              summaryFunc: at == null ? null : at[1] as String,
              fromClause: values[2] as FromClause?,
              whereClause: values[3] as Expr?,
            );
          });

  Parser<JournalStatement> journal() =>
      (kw('JOURNAL') &
              ref0(stringLit).optional() &
              (kw('AT') & ref0(identifier)).optional() &
              ref0(fromPart).optional())
          .map((values) {
            final at = values[2] as List<dynamic>?;
            return JournalStatement(
              account: values[1] as String?,
              summaryFunc: at == null ? null : at[1] as String,
              fromClause: values[3] as FromClause?,
            );
          });

  Parser<PrintStatement> printStmt() =>
      (kw('PRINT') & ref0(fromPart).optional()).map((values) => PrintStatement(fromClause: values[1] as FromClause?));

  Parser<CreateTableStatement> createTable() {
    final columns = (token(char('(')) & commaSeparated(columnDecl()) & token(char(')')))
        .pick(1)
        .cast<List<(String, String)>>();
    final using = (kw('USING') & stringLit()).pick(1).cast<String>();
    final asQuery = (kw('AS') & ref0(select)).pick(1).cast<SelectStatement>();
    final body =
        ((columns & using.optional()).map(
                  (values) => (values[0] as List<(String, String)>, values[1] as String?, null),
                ) |
                using.map((u) => (null, u, null)) |
                asQuery.map((q) => (null, null, q)))
            .cast<(List<(String, String)>?, String?, SelectStatement?)>();
    return (kw('CREATE') & kw('TABLE') & identifier() & body).map((values) {
      final parts = values[3] as (List<(String, String)>?, String?, SelectStatement?);
      return CreateTableStatement(name: values[2] as String, columns: parts.$1, using: parts.$2, query: parts.$3);
    });
  }

  Parser<(String, String)> columnDecl() =>
      (identifier() & identifier()).map((values) => (values[0] as String, values[1] as String));

  Parser<InsertStatement> insert() =>
      (kw('INSERT') &
              kw('INTO') &
              tableName() &
              (token(char('(')) & commaSeparated(column()) & token(char(')'))).optional() &
              kw('VALUES') &
              token(char('(')) &
              commaSeparated(ref0(expression)) &
              token(char(')')))
          .map((values) {
            final cols = values[3] as List<dynamic>?;
            return InsertStatement(
              table: values[2] as TableRef,
              columns: cols == null ? null : [for (final column in cols[1] as List<ColumnExpr>) column],
              values: values[6] as List<Expr>,
            );
          });

  Parser<TableRef> tableName() => identifier().map(TableRef.new);

  Parser<List<T>> commaSeparated<T>(Parser<T> item) => (item & (token(char(',')) & item).star()).map((values) {
    final first = values[0] as T;
    final rest = [for (final pair in values[1] as List<dynamic>) (pair as List<dynamic>)[1] as T];
    return [first, ...rest];
  });

  Parser<Expr> expression() => ref0(disjunction);

  Parser<Expr> disjunction() => (ref0(conjunction) & (kw('OR') & ref0(conjunction)).star()).map((values) {
    final first = values[0] as Expr;
    final rest = [for (final pair in values[1] as List<dynamic>) (pair as List<dynamic>)[1] as Expr];
    if (rest.isEmpty) return first;
    return Expr.or([first, ...rest]);
  });

  Parser<Expr> conjunction() => (ref0(inversion) & (kw('AND') & ref0(inversion)).star()).map((values) {
    final first = values[0] as Expr;
    final rest = [for (final pair in values[1] as List<dynamic>) (pair as List<dynamic>)[1] as Expr];
    if (rest.isEmpty) return first;
    return Expr.and([first, ...rest]);
  });

  Parser<Expr> inversion() => (kw('NOT').star() & ref0(comparison)).map((values) {
    var expr = values[1] as Expr;
    final nots = values[0] as List<dynamic>;
    for (var i = 0; i < nots.length; i++) {
      expr = Expr.not(expr);
    }
    return expr;
  });

  Parser<Expr> comparison() {
    final op = token(
      (string('<=') |
              string('>=') |
              string('!=') |
              string('!~') |
              string('?~') |
              char('<') |
              char('>') |
              char('=') |
              char('~'))
          .flatten(),
    );
    final anyAll =
        (ref0(sum) &
                op &
                token(
                  ((string('any', ignoreCase: true) | string('all', ignoreCase: true)) & pattern('a-zA-Z0-9_').not())
                      .flatten(),
                ) &
                token(char('(')) &
                ref0(expression) &
                token(char(')')))
            .map((values) {
              final kind = (values[2] as String).trim().toLowerCase();
              if (kind == 'any') {
                return Expr.any(left: values[0] as Expr, op: values[1] as String, right: values[4] as Expr);
              }
              return Expr.all(left: values[0] as Expr, op: values[1] as String, right: values[4] as Expr);
            });
    final rel = (ref0(sum) & relOp() & ref0(sum)).map((values) {
      final left = values[0] as Expr;
      final right = values[2] as Expr;
      return switch (values[1] as String) {
        '<' => Expr.lt(left, right),
        '<=' => Expr.lte(left, right),
        '>' => Expr.gt(left, right),
        '>=' => Expr.gte(left, right),
        '=' => Expr.eq(left, right),
        '!=' => Expr.neq(left, right),
        '~' => Expr.match(left, right),
        '!~' => Expr.notMatch(left, right),
        '?~' => Expr.matches(left, right),
        _ => throw StateError('unknown op'),
      };
    });
    final inOp = (ref0(sum) & kw('IN') & ref0(sum)).map((values) => Expr.in_(values[0] as Expr, values[2] as Expr));
    final notIn = (ref0(sum) & kw('NOT') & kw('IN') & ref0(sum)).map(
      (values) => Expr.notIn(values[0] as Expr, values[3] as Expr),
    );
    final isNull = (ref0(sum) & kw('IS') & kw('NULL')).map((values) => Expr.isNull(values[0] as Expr));
    final isNotNull = (ref0(sum) & kw('IS') & kw('NOT') & kw('NULL')).map(
      (values) => Expr.isNotNull(values[0] as Expr),
    );
    final between = (ref0(sum) & kw('BETWEEN') & ref0(sum) & kw('AND') & ref0(sum)).map(
      (values) => Expr.between(operand: values[0] as Expr, lower: values[2] as Expr, upper: values[4] as Expr),
    );
    return (anyAll | notIn | inOp | isNotNull | isNull | between | rel | ref0(sum)).cast<Expr>();
  }

  Parser<String> relOp() => token(
    (string('<=') |
            string('>=') |
            string('!=') |
            string('!~') |
            string('?~') |
            char('<') |
            char('>') |
            char('=') |
            char('~'))
        .flatten(),
  );

  Parser<Expr> sum() => (ref0(term) & (sumOp() & ref0(term)).star()).map((values) {
    var left = values[0] as Expr;
    for (final pair in values[1] as List<dynamic>) {
      final parts = pair as List<dynamic>;
      final right = parts[1] as Expr;
      left = parts[0] == '+' ? Expr.add(left, right) : Expr.sub(left, right);
    }
    return left;
  });

  Parser<String> sumOp() => token((char('+') | char('-')).flatten());

  Parser<Expr> term() => (ref0(factor) & (termOp() & ref0(factor)).star()).map((values) {
    var left = values[0] as Expr;
    for (final pair in values[1] as List<dynamic>) {
      final parts = pair as List<dynamic>;
      final right = parts[1] as Expr;
      left = switch (parts[0] as String) {
        '*' => Expr.mul(left, right),
        '/' => Expr.div(left, right),
        _ => Expr.mod(left, right),
      };
    }
    return left;
  });

  Parser<String> termOp() => token((char('*') | char('/') | char('%')).flatten());

  Parser<Expr> factor() =>
      (ref0(unary) | (token(char('(')) & ref0(expression) & token(char(')'))).pick(1).cast<Expr>()).cast<Expr>();

  Parser<Expr> unary() =>
      ((token(char('+')) & ref0(atom)).pick(1).cast<Expr>() |
              (token(char('-')) & ref0(factor)).map((values) => Expr.neg(values[1] as Expr)) |
              ref0(primary))
          .cast<Expr>();

  Parser<Expr> primary() {
    final start = atom();
    final suffix =
        (token(char('.')) & identifier()).map((values) => (kind: 'attr', value: values[1] as String)) |
        (token(char('[')) & stringLit() & token(char(']'))).map((values) => (kind: 'sub', value: values[1] as String));
    return (start & suffix.star()).map((values) {
      var expr = values[0] as Expr;
      for (final s in values[1] as List<dynamic>) {
        final suffix = s as ({String kind, String value});
        expr = suffix.kind == 'attr' ? Expr.attribute(expr, suffix.value) : Expr.subscript(expr, suffix.value);
      }
      return expr;
    });
  }

  Parser<Expr> atom() =>
      (ref0(selectExpr) | ref0(functionCall) | ref0(constant) | ref0(placeholder) | ref0(column)).cast<Expr>();

  Parser<Expr> selectExpr() =>
      (token(char('(')) & ref0(select) & token(char(')'))).pick(1).map((s) => Expr.select(s as SelectStatement));

  Parser<Expr> functionCall() {
    final args = commaSeparated(ref0(expression)).optional().map((v) => v ?? const <Expr>[]);
    final star = asterisk().map<List<Object>>((_) => [const Asterisk()]);
    return (identifier() & token(char('(')) & (star | args).cast<List<Object>>() & token(char(')'))).map((values) {
      return Expr.function(values[0] as String, values[2] as List<Object>);
    });
  }

  Parser<ColumnExpr> column() => identifier().map((name) => Expr.column(name) as ColumnExpr);

  Parser<Expr> placeholder() =>
      (token(string('%s')).map((_) => const Expr.placeholder(null)) |
              token((string('%(') & pattern('a-zA-Z_') & pattern('a-zA-Z0-9_').star() & string(')s')).flatten()).map((
                lexeme,
              ) {
                final name = lexeme.substring(2, lexeme.length - 2);
                return Expr.placeholder(name);
              }))
          .cast<Expr>();

  Parser<Expr> constant() => (listLiteral() | literal()).map(Expr.constant);

  Parser<Object?> literal() =>
      (dateLit() | decimalLit() | integerLit() | stringLit() | nullLit() | booleanLit()).cast<Object?>();

  Parser<Object?> listLiteral() {
    const empty = _ListEmpty();
    final lookahead = (token(char('(')) & literal() & token(char(','))).and();
    final elem = (literal() | epsilon().map((_) => empty)).cast<Object?>();
    return (lookahead & token(char('(')) & commaSeparated(elem) & token(char(')'))).map((values) {
      final items = values[2] as List<Object?>;
      return [
        for (final item in items)
          if (item is! _ListEmpty) item,
      ];
    });
  }

  Parser<String> identifier() => token((quotedIdentifier() | unquotedIdentifier()).cast<String>());

  Parser<String> unquotedIdentifier() => (pattern('a-zA-Z_') & pattern('a-zA-Z0-9_').star())
      .flatten()
      .where((name) => !_keywords.contains(name.toLowerCase()))
      .map((name) => name.toLowerCase());

  Parser<String> quotedIdentifier() =>
      (char('"') & (string('""') | pattern('^"')).plus().flatten() & char('"')).map((values) {
        return (values[1] as String).replaceAll('""', '"');
      });

  Parser<String> stringLit() => token((doubleQuoteString() | singleQuoteString()).cast<String>());

  Parser<String> doubleQuoteString() =>
      (char('"') & pattern('^"').star().flatten() & char('"')).map((values) => values[1] as String);

  Parser<String> singleQuoteString() =>
      (char("'") & (string("''") | pattern("^'")).star().flatten() & char("'")).map((values) => values[1] as String);

  Parser<bool> booleanLit() => token<bool>(
    ((string('TRUE', ignoreCase: true) & pattern('a-zA-Z0-9_').not()).map((_) => true) |
            (string('FALSE', ignoreCase: true) & pattern('a-zA-Z0-9_').not()).map((_) => false))
        .cast<bool>(),
  );

  Parser<Object?> nullLit() => token((string('NULL', ignoreCase: true) & pattern('a-zA-Z0-9_').not()).map((_) => null));

  Parser<int> integerLit() =>
      token((digit().plus().flatten() & char('.').not()).pick(0).map((value) => int.parse(value as String)));

  Parser<Decimal> decimalLit() =>
      token((digit().plus() & char('.') & digit().star() | char('.') & digit().plus()).flatten().map(Decimal.parse));

  Parser<BeanDate> dateLit() => token(
    (digit().times(4).flatten() & char('-') & digit().times(2).flatten() & char('-') & digit().times(2).flatten()).map((
      values,
    ) {
      return BeanDate(
        year: int.parse(values[0] as String),
        month: int.parse(values[2] as String),
        day: int.parse(values[4] as String),
      );
    }),
  );
}

class _ListEmpty {
  const _ListEmpty();
}

final _bqlParser = BqlGrammar().build();

Statement parseBql(String source) {
  final result = _bqlParser.parse(source.trim());
  switch (result) {
    case Success(:final value):
      return value;
    case Failure():
      throw QueryException('syntax error', location: BeanLocation(linenoBegin: 1, linenoEnd: 1));
  }
}
