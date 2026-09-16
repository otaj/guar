// Ports of beanquery query_execute_test.py against a booked ledger.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:guar_query/guar_query.dart';
import 'package:test/test.dart';

Ledger book(String source) {
  final parsed = const p.BeancountParser().parse(source, filename: 'test.beancount');
  final booked = Book().process(parsed);
  expect(booked, isA<LedgerDirectives>(), reason: booked is LedgerErrors ? booked.errors.toString() : null);
  return booked;
}

QueryTable run(Ledger ledger, String query) {
  final result = Query(clock: () => DateTime.utc(2022, 4, 5)).run(ledger, query);
  expect(
    result,
    isA<QueryTable>(),
    reason: result is QueryErrors ? result.errors.toString() : result.runtimeType.toString(),
  );
  return result as QueryTable;
}

void expectError(Ledger ledger, String query) {
  final result = Query().run(ledger, query);
  expect(result, isA<QueryErrors>());
}

QueryValue n(String number) => QueryValue.number(Decimal.parse(number));

const common = '''
2010-01-01 open Assets:Bank:Checking
2010-01-01 open Assets:ForeignBank:Checking
2010-01-01 open Assets:Bank:Savings

2010-01-01 open Expenses:Restaurant
2010-01-01 open Equity:Opening-Balances

2010-01-01 * "Dinner with Cero"
  Assets:Bank:Checking 100.00 USD
  Expenses:Restaurant -100.00 USD

2011-01-01 * "Dinner with Uno"
  Assets:Bank:Checking 101.00 USD
  Expenses:Restaurant -101.00 USD

2012-02-02 * "Dinner with Dos"
  Assets:Bank:Checking 102.00 USD
  Expenses:Restaurant -102.00 USD

2013-03-03 * "Dinner with Tres"
  Assets:Bank:Checking 103.00 USD
  Expenses:Restaurant -103.00 USD

2013-10-10 * "International Transfer"
  Assets:Bank:Checking -50.00 USD
  Assets:ForeignBank:Checking -60.00 CAD @ 1.20 USD
  Equity:Opening-Balances

2014-04-04 * "Dinner with Quatro"
  Assets:Bank:Checking 104.00 USD
  Expenses:Restaurant -104.00 USD
''';

void main() {
  late Ledger fundamentals;
  late Ledger dinner;

  setUpAll(() {
    fundamentals = book('''
2022-04-05 commodity TEST
  rate: 42
2022-04-05 open Assets:Tests
2022-04-05 open Equity:Opening-Balances
2022-04-05 * "Test"
  Assets:Tests 1.000 TEST
    int: 1
    decimal: 1.2
    bool: TRUE
    str: "str"
    str3: "3"
    str4: "4.0"
    date: 2022-04-05
    null: NULL
  Equity:Opening-Balances
''');
    dinner = book(common);
  });

  group('casts', () {
    test('bool int decimal str date', () {
      expect(run(fundamentals, 'SELECT bool(TRUE)').rows.first.values.single, const QueryValue.boolean(true));
      expect(run(fundamentals, 'SELECT bool(1)').rows.first.values.single, const QueryValue.boolean(true));
      expect(run(fundamentals, 'SELECT int(TRUE)').rows.first.values.single, const QueryValue.integer(1));
      expect(run(fundamentals, 'SELECT int(1.2)').rows.first.values.single, const QueryValue.integer(1));
      expect(run(fundamentals, 'SELECT decimal(1)').rows.first.values.single, n('1'));
      expect(run(fundamentals, "SELECT str(TRUE)").rows.first.values.single, const QueryValue.text('TRUE'));
      expect(
        run(fundamentals, 'SELECT date(2022-04-05)').rows.first.values.single,
        QueryValue.date(BeanDate(year: 2022, month: 4, day: 5)),
      );
    });
  });

  group('select postings', () {
    test('filter by year', () {
      final table = run(dinner, "SELECT date, narration WHERE year = 2012");
      expect(table.rows, hasLength(2));
      expect(table.rows.first.values[1], const QueryValue.text('Dinner with Dos'));
    });

    test('sum position grouped by account', () {
      final table = run(dinner, 'SELECT account, sum(position) WHERE account ~ "Expenses" GROUP BY account');
      expect(table.rows, hasLength(1));
      expect(
        table.rows.single.values[0],
        QueryValue.account(Account(name: 'Expenses:Restaurant', type: AccountType.expenses)),
      );
      final inventory = table.rows.single.values[1] as QueryInventory;
      expect(inventory.value.positions, isNotEmpty);
    });

    test('distinct accounts', () {
      final table = run(dinner, 'SELECT DISTINCT account ORDER BY account');
      expect(table.rows.map((row) => (row.values.single as QueryAccount).value.name).toList(), [
        'Assets:Bank:Checking',
        'Assets:ForeignBank:Checking',
        'Equity:Opening-Balances',
        'Expenses:Restaurant',
      ]);
    });

    test('limit', () {
      final table = run(dinner, 'SELECT date LIMIT 3');
      expect(table.rows, hasLength(3));
    });

    test('order desc', () {
      final table = run(dinner, 'SELECT DISTINCT year ORDER BY year DESC');
      expect((table.rows.first.values.single as QueryInteger).value, 2014);
    });

    test('having', () {
      final table = run(dinner, 'SELECT account, count(*) GROUP BY account HAVING count(*) > 2 ORDER BY account');
      expect(table.rows, isNotEmpty);
      expect((table.rows.first.values[0] as QueryAccount).value.name, isNotEmpty);
    });
  });

  group('named tables', () {
    test('entries types', () {
      final table = run(dinner, 'SELECT type FROM #entries WHERE type = "open"');
      expect(table.rows, hasLength(5));
    });

    test('transactions', () {
      final table = run(dinner, 'SELECT narration FROM #transactions WHERE year = 2013');
      expect(table.rows.map((row) => (row.values.single as QueryText).value), [
        'Dinner with Tres',
        'International Transfer',
      ]);
    });
  });

  group('journal balances print', () {
    test('balances', () {
      final table = run(dinner, 'BALANCES');
      expect(table.columns.first.name, 'account');
      expect(table.rows, isNotEmpty);
    });

    test('print', () {
      final result = Query().run(dinner, 'PRINT FROM year = 2012');
      expect(result, isA<QueryEntries>());
      final entries = (result as QueryEntries).directives;
      expect(entries, isNotEmpty);
      expect(entries.every((entry) => entry.date.year == 2012), isTrue);
    });

    test('journal', () {
      final table = run(dinner, "JOURNAL 'Expenses:Restaurant'");
      expect(table.columns.map((column) => column.name).take(5).toList(), [
        'date',
        'flag',
        'maxwidth(payee, 48)',
        'maxwidth(narration, 80)',
        'account',
      ]);
      expect(table.rows, isNotEmpty);
    });
  });

  group('create table', () {
    test('compile error', () {
      expectError(dinner, 'CREATE TABLE abcd (a int, b bool, c str, d date)');
      expectError(dinner, "INSERT INTO abcd (a) VALUES (1)");
    });
  });

  group('open close clear', () {
    test('open dated inserts balances', () {
      final result = Query().run(dinner, 'PRINT FROM OPEN ON 2013-01-01');
      expect(result, isA<QueryEntries>());
      final entries = (result as QueryEntries).directives;
      expect(
        entries.any(
          (entry) => entry.body is TransactionBody && (entry.body as TransactionBody).value.flag == Flag.letter('S'),
        ),
        isTrue,
      );
    });

    test('clear transfers income statement', () {
      final result = Query().run(dinner, 'PRINT FROM CLEAR');
      expect(result, isA<QueryEntries>());
      final entries = (result as QueryEntries).directives;
      expect(
        entries.any(
          (entry) => entry.body is TransactionBody && (entry.body as TransactionBody).value.flag == Flag.letter('T'),
        ),
        isTrue,
      );
    });
  });

  group('pivot and subquery', () {
    test('subquery arithmetic', () {
      final table = run(dinner, 'SELECT a + 2 AS b FROM (SELECT 3 AS a FROM #)');
      expect(table.rows.first.values.single, const QueryValue.integer(5));
    });

    test('in list', () {
      final table = run(dinner, "SELECT DISTINCT year WHERE year IN (2012, 2013) ORDER BY year");
      expect(table.rows.map((row) => (row.values.single as QueryInteger).value).toList(), [2012, 2013]);
    });

    test('in subquery', () {
      final table = run(dinner, "SELECT DISTINCT account WHERE account IN (SELECT account WHERE account ~ 'Expenses')");
      expect(
        table.rows.single.values.single,
        QueryValue.account(Account(name: 'Expenses:Restaurant', type: AccountType.expenses)),
      );
    });

    test('any list', () {
      final table = run(dinner, 'SELECT DISTINCT year WHERE year = any((2012, 2014)) ORDER BY year');
      expect(table.rows.map((row) => (row.values.single as QueryInteger).value).toList(), [2012, 2014]);
    });

    test('meta subscript', () {
      final table = run(fundamentals, "SELECT meta['int']");
      expect((table.rows.first.values.single as QueryMetaCell).value, isA<MetaNumber>());
    });

    test('placeholders', () {
      final table =
          Query(
                clock: () => DateTime.utc(2022, 4, 5),
              ).run(dinner, 'SELECT DISTINCT year WHERE year = %(year)s', params: {'year': 2012})
              as QueryTable;
      expect((table.rows.single.values.single as QueryInteger).value, 2012);
    });

    test('today uses injectable clock', () {
      final table = run(dinner, 'SELECT DISTINCT today()');
      expect(table.rows.single.values.single, QueryValue.date(BeanDate(year: 2022, month: 4, day: 5)));
    });

    test('account functions', () {
      final table = run(dinner, "SELECT DISTINCT root(account, 1) WHERE account ~ 'Expenses'");
      expect(table.rows.single.values.single, const QueryValue.text('Expenses'));
    });

    test('pivot by year and account', () {
      final table = run(dinner, 'SELECT year, account, count(*) GROUP BY 1, 2 PIVOT BY 1, 2');
      expect(table.columns, isNotEmpty);
      expect(table.rows, isNotEmpty);
    });
  });

  group('error ledger', () {
    test('querying errors yields errors', () {
      final ledger = Ledger.errors(
        errors: [ProcessingError(message: 'boom', location: BeanLocation(linenoBegin: 1, linenoEnd: 1))],
      );
      expectError(ledger, 'SELECT account');
    });
  });
}
