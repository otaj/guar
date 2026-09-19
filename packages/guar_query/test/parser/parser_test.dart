// Ports of beanquery parser_test.py for BQL syntax.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_query/guar_query.dart';
import 'package:test/test.dart';

SelectStatement select(
  Object targets, {
  FromClause? fromClause,
  Expr? whereClause,
  GroupBy? groupBy,
  List<OrderBy>? orderBy,
  PivotBy? pivotBy,
  int? limit,
  bool? distinct,
}) => SelectStatement(
  targets: targets,
  fromClause: fromClause,
  whereClause: whereClause,
  groupBy: groupBy,
  orderBy: orderBy,
  pivotBy: pivotBy,
  limit: limit,
  distinct: distinct,
);

void assertParse(String query, Statement expected) {
  expect(Query().parse(query), expected);
}

void assertParseTarget(String query, Expr expected) {
  final Statement parsed = Query().parse(query);
  expect(parsed, isA<SelectStatement>());
  final SelectStatement statement = parsed as SelectStatement;
  final List<Target> targets = statement.targets as List<Target>;
  expect(targets, hasLength(1));
  expect(targets.single.expression, expected);
}

void assertParseFrom(String query, FromClause expected) {
  final Statement parsed = Query().parse(query);
  expect(parsed, isA<SelectStatement>());
  expect((parsed as SelectStatement).fromClause, expected);
}

void assertParseError(String query) {
  expect(() => Query().parse(query), throwsA(isA<QueryException>()));
}

BeanDate d(int y, int m, int day) => BeanDate(year: y, month: m, day: day);

void main() {
  group('SELECT', () {
    test('empty select is a syntax error', () {
      assertParseError('SELECT');
      assertParseError('SELECT ; ');
    });

    test('wildcard', () {
      assertParse('SELECT *;', select(const Asterisk()));
    });

    test('columns and aliases', () {
      assertParse('SELECT date;', select(<Target>[const Target(expression: Expr.column('date'))]));
      assertParse(
        'SELECT date, account',
        select(<Target>[
          const Target(expression: Expr.column('date')),
          const Target(expression: Expr.column('account')),
        ]),
      );
      assertParse(
        'SELECT date as xdate;',
        select(<Target>[const Target(expression: Expr.column('date'), name: 'xdate')]),
      );
      assertParse(
        'SELECT date as x, account, position as y;',
        select(<Target>[
          const Target(expression: Expr.column('date'), name: 'x'),
          const Target(expression: Expr.column('account')),
          const Target(expression: Expr.column('position'), name: 'y'),
        ]),
      );
    });

    test('literals', () {
      assertParseTarget('SELECT (1);', const Expr.constant(1));
      assertParseTarget('SELECT (1, );', const Expr.constant(<int>[1]));
      assertParseTarget('SELECT (1, 2);', const Expr.constant(<int>[1, 2]));
      assertParseTarget('SELECT (1, 2, );', const Expr.constant(<int>[1, 2]));
      assertParseTarget("SELECT ('x', 'y', 'z');", const Expr.constant(<String>['x', 'y', 'z']));
      assertParseTarget('SELECT date;', const Expr.column('date'));
    });

    test('attributes subscripts and quantified', () {
      assertParseTarget('SELECT date.year;', const Expr.attribute(Expr.column('date'), 'year'));
      assertParseTarget("SELECT meta['key'];", const Expr.subscript(Expr.column('meta'), 'key'));
      assertParseTarget(
        'SELECT a BETWEEN 1 AND 3;',
        const Expr.between(operand: Expr.column('a'), lower: Expr.constant(1), upper: Expr.constant(3)),
      );
      assertParseTarget("SELECT a IN ('x', 'y');", const Expr.in_(Expr.column('a'), Expr.constant(<String>['x', 'y'])));
      assertParseTarget(
        'SELECT a = any((1, 2));',
        const Expr.any(left: Expr.column('a'), op: '=', right: Expr.constant(<int>[1, 2])),
      );
      assertParseTarget(
        'SELECT a = all((1, 2));',
        const Expr.all(left: Expr.column('a'), op: '=', right: Expr.constant(<int>[1, 2])),
      );
    });

    test('comparison operators', () {
      assertParseTarget('SELECT a = 42;', const Expr.eq(Expr.column('a'), Expr.constant(42)));
      assertParseTarget('SELECT a != 42;', const Expr.neq(Expr.column('a'), Expr.constant(42)));
      assertParseTarget('SELECT a > 42;', const Expr.gt(Expr.column('a'), Expr.constant(42)));
      assertParseTarget('SELECT a >= 42;', const Expr.gte(Expr.column('a'), Expr.constant(42)));
      assertParseTarget('SELECT a < 42;', const Expr.lt(Expr.column('a'), Expr.constant(42)));
      assertParseTarget('SELECT a <= 42;', const Expr.lte(Expr.column('a'), Expr.constant(42)));
      assertParseTarget("SELECT a ~ 'abc';", const Expr.match(Expr.column('a'), Expr.constant('abc')));
      assertParseTarget('SELECT not a;', const Expr.not(Expr.column('a')));
      assertParseTarget('SELECT a IS NULL;', const Expr.isNull(Expr.column('a')));
      assertParseTarget('SELECT a IS NOT NULL;', const Expr.isNotNull(Expr.column('a')));
    });

    test('boolean expressions', () {
      assertParseTarget('SELECT a AND b;', const Expr.and(<Expr>[Expr.column('a'), Expr.column('b')]));
      assertParseTarget(
        'SELECT a AND b AND c;',
        const Expr.and(<Expr>[Expr.column('a'), Expr.column('b'), Expr.column('c')]),
      );
      assertParseTarget('SELECT a OR b;', const Expr.or(<Expr>[Expr.column('a'), Expr.column('b')]));
      assertParseTarget(
        'SELECT a OR b OR c;',
        const Expr.or(<Expr>[Expr.column('a'), Expr.column('b'), Expr.column('c')]),
      );
      assertParseTarget(
        'SELECT a AND b OR c;',
        const Expr.or(<Expr>[
          Expr.and(<Expr>[Expr.column('a'), Expr.column('b')]),
          Expr.column('c'),
        ]),
      );
      assertParseTarget('SELECT NOT a;', const Expr.not(Expr.column('a')));
    });

    test('math expressions', () {
      assertParseTarget('SELECT a * b;', const Expr.mul(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT a / b;', const Expr.div(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT a + b;', const Expr.add(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT a+b;', const Expr.add(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT a - b;', const Expr.sub(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT a-b;', const Expr.sub(Expr.column('a'), Expr.column('b')));
      assertParseTarget('SELECT +a;', const Expr.column('a'));
      assertParseTarget('SELECT -a;', const Expr.neg(Expr.column('a')));
      assertParseTarget('SELECT 2 * 3;', const Expr.mul(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2 / 3;', const Expr.div(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2+(3);', const Expr.add(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT (2)-3;', const Expr.sub(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2 + 3;', const Expr.add(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2+3;', const Expr.add(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2 - 3;', const Expr.sub(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT 2-3;', const Expr.sub(Expr.constant(2), Expr.constant(3)));
      assertParseTarget('SELECT +2;', const Expr.constant(2));
      assertParseTarget('SELECT -2;', const Expr.neg(Expr.constant(2)));
      assertParseTarget("SELECT -'abc';", const Expr.neg(Expr.constant('abc')));
    });

    test('functions', () {
      assertParseTarget('SELECT random();', const Expr.function('random', <Object>[]));
      assertParseTarget('SELECT min(a);', const Expr.function('min', <Object>[Expr.column('a')]));
      assertParseTarget('SELECT min(a, b);', const Expr.function('min', <Object>[Expr.column('a'), Expr.column('b')]));
      assertParseTarget('SELECT count(*);', const Expr.function('count', <Object>[Asterisk()]));
    });

    test('non-associative comparisons', () {
      assertParseError('SELECT 3 > 2 > 1');
      assertParseError('SELECT 3 = 2 = 1');
    });

    test('complex expressions', () {
      assertParseTarget(
        'SELECT NOT a = (b != (42 AND 17));',
        const Expr.not(
          Expr.eq(Expr.column('a'), Expr.neq(Expr.column('b'), Expr.and(<Expr>[Expr.constant(42), Expr.constant(17)]))),
        ),
      );
    });
  });

  group('precedence', () {
    test('operators', () {
      assertParseTarget(
        'SELECT a AND b OR c AND d;',
        const Expr.or(<Expr>[
          Expr.and(<Expr>[Expr.column('a'), Expr.column('b')]),
          Expr.and(<Expr>[Expr.column('c'), Expr.column('d')]),
        ]),
      );
      assertParseTarget(
        'SELECT a = 2 AND b != 3;',
        const Expr.and(<Expr>[
          Expr.eq(Expr.column('a'), Expr.constant(2)),
          Expr.neq(Expr.column('b'), Expr.constant(3)),
        ]),
      );
      assertParseTarget('SELECT not a AND b;', const Expr.and(<Expr>[Expr.not(Expr.column('a')), Expr.column('b')]));
      assertParseTarget(
        'SELECT a + b AND c - d;',
        const Expr.and(<Expr>[
          Expr.add(Expr.column('a'), Expr.column('b')),
          Expr.sub(Expr.column('c'), Expr.column('d')),
        ]),
      );
      assertParseTarget(
        'SELECT a * b + c / d - 3;',
        const Expr.sub(
          Expr.add(Expr.mul(Expr.column('a'), Expr.column('b')), Expr.div(Expr.column('c'), Expr.column('d'))),
          Expr.constant(3),
        ),
      );
      assertParseTarget(
        "SELECT 'orange' IN tags AND 'bananas' IN tags;",
        const Expr.and(<Expr>[
          Expr.in_(Expr.constant('orange'), Expr.column('tags')),
          Expr.in_(Expr.constant('bananas'), Expr.column('tags')),
        ]),
      );
    });
  });

  group('FROM', () {
    const Expr expr = Expr.eq(
      Expr.column('d'),
      Expr.and(<Expr>[
        Expr.function('max', <Object>[Expr.column('e')]),
        Expr.constant(17),
      ]),
    );

    test('missing from expression is a syntax error', () {
      assertParseError('SELECT a, b FROM;');
    });

    test('simple from', () {
      assertParseFrom('SELECT a, b FROM d = (max(e) and 17);', const FromClause.filter(expression: expr));
    });

    test('named tables', () {
      assertParseFrom('SELECT a FROM #test;', const FromClause.table('test'));
      assertParseFrom('SELECT a FROM #;', const FromClause.table(''));
    });

    test('open close clear', () {
      assertParseFrom(
        'SELECT a, b FROM d = (max(e) and 17) OPEN ON 2014-01-01;',
        FromClause.filter(expression: expr, open: d(2014, 1, 1)),
      );
      assertParseFrom(
        'SELECT a, b FROM d = (max(e) and 17) CLOSE;',
        const FromClause.filter(expression: expr, close: CloseSpec.end()),
      );
      assertParseFrom(
        'SELECT a, b FROM d = (max(e) and 17) CLOSE ON 2014-10-18;',
        FromClause.filter(expression: expr, close: CloseSpec.on(d(2014, 10, 18))),
      );
      assertParseFrom('SELECT a, b FROM CLOSE;', const FromClause.filter(close: CloseSpec.end()));
      assertParseFrom('SELECT a, b FROM CLOSE ON 2014-10-18;', FromClause.filter(close: CloseSpec.on(d(2014, 10, 18))));
      assertParseFrom(
        'SELECT a, b FROM d = (max(e) and 17) CLEAR;',
        const FromClause.filter(expression: expr, clear: true),
      );
      assertParseFrom(
        'SELECT a, b FROM d = (max(e) and 17) OPEN ON 2013-10-25 CLOSE ON 2014-10-25 CLEAR;',
        FromClause.filter(expression: expr, open: d(2013, 10, 25), close: CloseSpec.on(d(2014, 10, 25)), clear: true),
      );
    });
  });

  group('WHERE', () {
    test('where clause', () {
      const Expr expr = Expr.eq(
        Expr.column('d'),
        Expr.and(<Expr>[
          Expr.function('max', <Object>[Expr.column('e')]),
          Expr.constant(17),
        ]),
      );
      assertParse(
        'SELECT a, b WHERE d = (max(e) and 17);',
        select(<Target>[
          const Target(expression: Expr.column('a')),
          const Target(expression: Expr.column('b')),
        ], whereClause: expr),
      );
      assertParseError('SELECT a, b WHERE;');
    });
  });

  group('FROM and WHERE', () {
    test('both clauses', () {
      const Expr expr = Expr.eq(
        Expr.column('d'),
        Expr.and(<Expr>[
          Expr.function('max', <Object>[Expr.column('e')]),
          Expr.constant(17),
        ]),
      );
      assertParse(
        'SELECT a, b FROM d = (max(e) and 17) WHERE d = (max(e) and 17);',
        select(
          <Target>[const Target(expression: Expr.column('a')), const Target(expression: Expr.column('b'))],
          fromClause: const FromClause.filter(expression: expr),
          whereClause: expr,
        ),
      );
    });
  });

  group('subselect', () {
    test('from select', () {
      assertParse(
        '''
 SELECT a, b FROM (
 SELECT * FROM date = 2014-05-02
 ) WHERE c = 5 LIMIT 100;''',
        select(
          <Target>[const Target(expression: Expr.column('a')), const Target(expression: Expr.column('b'))],
          fromClause: FromClause.subselect(
            select(
              const Asterisk(),
              fromClause: FromClause.filter(
                expression: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 5, 2))),
              ),
            ),
          ),
          whereClause: const Expr.eq(Expr.column('c'), Expr.constant(5)),
          limit: 100,
        ),
      );
    });
  });

  group('GROUP BY', () {
    test('columns expressions having and numbers', () {
      assertParse(
        'SELECT * GROUP BY a;',
        select(const Asterisk(), groupBy: const GroupBy(columns: <Object>[Expr.column('a')])),
      );
      assertParse(
        'SELECT * GROUP BY a, b, c;',
        select(
          const Asterisk(),
          groupBy: const GroupBy(columns: <Object>[Expr.column('a'), Expr.column('b'), Expr.column('c')]),
        ),
      );
      assertParse(
        'SELECT * GROUP BY length(a) > 0, b;',
        select(
          const Asterisk(),
          groupBy: const GroupBy(
            columns: <Object>[
              Expr.gt(Expr.function('length', <Object>[Expr.column('a')]), Expr.constant(0)),
              Expr.column('b'),
            ],
          ),
        ),
      );
      assertParse(
        'SELECT * GROUP BY a HAVING sum(x) = 0;',
        select(
          const Asterisk(),
          groupBy: const GroupBy(
            columns: <Object>[Expr.column('a')],
            having: Expr.eq(Expr.function('sum', <Object>[Expr.column('x')]), Expr.constant(0)),
          ),
        ),
      );
      assertParse('SELECT * GROUP BY 1;', select(const Asterisk(), groupBy: const GroupBy(columns: <Object>[1])));
      assertParse(
        'SELECT * GROUP BY 2, 4, 5;',
        select(const Asterisk(), groupBy: const GroupBy(columns: <Object>[2, 4, 5])),
      );
      assertParseError('SELECT * GROUP BY;');
    });
  });

  group('ORDER BY', () {
    test('direction and many columns', () {
      assertParse(
        'SELECT * ORDER BY a;',
        select(const Asterisk(), orderBy: <OrderBy>[const OrderBy(column: Expr.column('a'))]),
      );
      assertParse(
        'SELECT * ORDER BY a, b, c;',
        select(
          const Asterisk(),
          orderBy: <OrderBy>[
            const OrderBy(column: Expr.column('a')),
            const OrderBy(column: Expr.column('b')),
            const OrderBy(column: Expr.column('c')),
          ],
        ),
      );
      assertParse(
        'SELECT * ORDER BY a ASC;',
        select(const Asterisk(), orderBy: <OrderBy>[const OrderBy(column: Expr.column('a'))]),
      );
      assertParse(
        'SELECT * ORDER BY a DESC;',
        select(
          const Asterisk(),
          orderBy: <OrderBy>[const OrderBy(column: Expr.column('a'), ordering: Ordering.desc)],
        ),
      );
      assertParse(
        'SELECT * ORDER BY a ASC, b DESC, c;',
        select(
          const Asterisk(),
          orderBy: <OrderBy>[
            const OrderBy(column: Expr.column('a')),
            const OrderBy(column: Expr.column('b'), ordering: Ordering.desc),
            const OrderBy(column: Expr.column('c')),
          ],
        ),
      );
      assertParseError('SELECT * ORDER BY;');
    });
  });

  group('PIVOT BY', () {
    test('two columns', () {
      assertParseError('SELECT * PIVOT BY;');
      assertParseError('SELECT * PIVOT BY a;');
      assertParseError('SELECT * PIVOT BY a, b, c');
      assertParse(
        'SELECT * PIVOT BY a, b',
        select(const Asterisk(), pivotBy: const PivotBy(columns: <Object>[Expr.column('a'), Expr.column('b')])),
      );
      assertParse('SELECT * PIVOT BY 1, 2', select(const Asterisk(), pivotBy: const PivotBy(columns: <Object>[1, 2])));
    });
  });

  group('options', () {
    test('distinct and limit', () {
      assertParse('SELECT DISTINCT x;', select(<Target>[const Target(expression: Expr.column('x'))], distinct: true));
      assertParse('SELECT * LIMIT 45;', select(const Asterisk(), limit: 45));
      assertParseError('SELECT * LIMIT;');
    });
  });

  group('BALANCES JOURNAL PRINT', () {
    test('balances', () {
      assertParse('BALANCES;', const BalancesStatement());
      assertParse(
        'BALANCES FROM date = 2014-01-01 CLOSE;',
        BalancesStatement(
          fromClause: FromClause.filter(
            expression: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 1, 1))),
            close: const CloseSpec.end(),
          ),
        ),
      );
      assertParse(
        'BALANCES AT units FROM date = 2014-01-01 CLOSE;',
        BalancesStatement(
          summaryFunc: 'units',
          fromClause: FromClause.filter(
            expression: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 1, 1))),
            close: const CloseSpec.end(),
          ),
        ),
      );
      assertParse(
        'BALANCES AT units WHERE date = 2014-01-01;',
        BalancesStatement(
          summaryFunc: 'units',
          whereClause: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 1, 1))),
        ),
      );
    });

    test('journal', () {
      assertParse('JOURNAL;', const JournalStatement());
      assertParse("JOURNAL 'Assets:Checking';", const JournalStatement(account: 'Assets:Checking'));
      assertParse('JOURNAL AT cost;', const JournalStatement(summaryFunc: 'cost'));
      assertParse("JOURNAL 'Assets:Foo' AT cost;", const JournalStatement(account: 'Assets:Foo', summaryFunc: 'cost'));
      assertParse(
        'JOURNAL FROM date = 2014-01-01 CLOSE;',
        JournalStatement(
          fromClause: FromClause.filter(
            expression: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 1, 1))),
            close: const CloseSpec.end(),
          ),
        ),
      );
    });

    test('print', () {
      assertParse('PRINT;', const PrintStatement());
      assertParse(
        'PRINT FROM date = 2014-01-01 CLOSE;',
        PrintStatement(
          fromClause: FromClause.filter(
            expression: Expr.eq(const Expr.column('date'), Expr.constant(d(2014, 1, 1))),
            close: const CloseSpec.end(),
          ),
        ),
      );
    });
  });

  group('comments', () {
    test('block comments', () {
      assertParse(
        'SELECT first, /* comment */ second',
        select(<Target>[
          const Target(expression: Expr.column('first')),
          const Target(expression: Expr.column('second')),
        ]),
      );
      assertParse(
        '''
SELECT first, /*
 comment
 */ second;''',
        select(<Target>[
          const Target(expression: Expr.column('first')),
          const Target(expression: Expr.column('second')),
        ]),
      );
      assertParse(
        'SELECT first, /**/ second;',
        select(<Target>[
          const Target(expression: Expr.column('first')),
          const Target(expression: Expr.column('second')),
        ]),
      );
      assertParse(
        'SELECT first, /* /* */ second;',
        select(<Target>[
          const Target(expression: Expr.column('first')),
          const Target(expression: Expr.column('second')),
        ]),
      );
      assertParse(
        'SELECT first, /* ; */ second;',
        select(<Target>[
          const Target(expression: Expr.column('first')),
          const Target(expression: Expr.column('second')),
        ]),
      );
    });
  });

  group('identifiers and literals', () {
    test('unquoted identifiers fold case', () {
      expect(Query().parse('SELECT Foo;'), select(<Target>[const Target(expression: Expr.column('foo'))]));
    });

    test('quoted identifiers', () {
      expect(Query().parse('SELECT "foo";'), select(<Target>[const Target(expression: Expr.constant('foo'))]));
      expect(
        Query().parse('SELECT "foo bar" as "x";'),
        select(<Target>[const Target(expression: Expr.constant('foo bar'), name: 'x')]),
      );
    });

    test('literal values', () {
      assertParseTarget('SELECT NULL;', const Expr.constant(null));
      assertParseTarget('SELECT TRUE;', const Expr.constant(true));
      assertParseTarget('SELECT FALSE;', const Expr.constant(false));
      assertParseTarget('SELECT 17;', const Expr.constant(17));
      assertParseTarget('SELECT 17.345;', Expr.constant(Decimal.parse('17.345')));
      assertParseTarget('SELECT .345;', Expr.constant(Decimal.parse('.345')));
      assertParseTarget('SELECT 17.;', Expr.constant(Decimal.parse('17.')));
      assertParseTarget("SELECT 'rainy-day';", const Expr.constant('rainy-day'));
      assertParseTarget("SELECT 'rainy''day';", const Expr.constant("rainy''day"));
      assertParseTarget('SELECT 1972-05-28;', Expr.constant(d(1972, 5, 28)));
    });
  });

  group('CREATE TABLE and INSERT', () {
    test('parse create table', () {
      expect(
        Query().parse('CREATE TABLE abcd (a int, b bool, c str, d date)'),
        const CreateTableStatement(
          name: 'abcd',
          columns: <(String, String)>[('a', 'int'), ('b', 'bool'), ('c', 'str'), ('d', 'date')],
        ),
      );
      expect(
        Query().parse("CREATE TABLE csv USING 'file.csv'"),
        const CreateTableStatement(name: 'csv', using: 'file.csv'),
      );
      expect(
        Query().parse('CREATE TABLE t AS SELECT 1'),
        CreateTableStatement(
          name: 't',
          query: select(<Target>[const Target(expression: Expr.constant(1))]),
        ),
      );
    });

    test('parse insert', () {
      expect(
        Query().parse("INSERT INTO abcd (a, b, c, d) VALUES (1, TRUE, 'one', 2025-01-01)"),
        InsertStatement(
          table: const TableRef('abcd'),
          columns: <Expr>[
            const Expr.column('a'),
            const Expr.column('b'),
            const Expr.column('c'),
            const Expr.column('d'),
          ],
          values: <Expr>[
            const Expr.constant(1),
            const Expr.constant(true),
            const Expr.constant('one'),
            Expr.constant(d(2025, 1, 1)),
          ],
        ),
      );
    });
  });

  group('placeholders', () {
    test('named and positional', () {
      assertParseTarget('SELECT %(foo)s;', const Expr.placeholder('foo'));
      assertParseTarget('SELECT %s;', const Expr.placeholder(null));
    });
  });
}
