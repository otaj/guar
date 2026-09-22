# guar_query

Beancount Query Language (BQL) for a booked guar ledger.

This package parses beanquery syntax and runs `SELECT`, `JOURNAL`, `BALANCES`, and `PRINT` against a `guar_domain` `Ledger`. Parsing Beancount source belongs to `guar_parser`. Booking belongs to `guar_book`.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                                          │
                                          ▼
                                     guar_query  ──►  QueryResult
```

`lib/` depends on `guar_domain` only. Tests parse and book fixtures through `guar_parser` and `guar_book`.

## Public API

```dart
import 'package:guar_query/guar_query.dart';

final result = Query().run(
  ledger,
  'SELECT account, sum(position) WHERE account ~ "Expenses:" GROUP BY account',
);

switch (result) {
  case QueryTable(:final columns, :final rows):
    // columns: name + QueryType; rows: List<QueryValue>
  case QueryEntries(:final directives):
    // PRINT / JOURNAL yield booked directives
  case QueryErrors(:final errors):
    // error.message, error.location
}
```

`parse` returns a `Statement`. `execute` compiles and runs one. `run` does both. `Query(clock: …)` supplies the clock used by `NOW()` and similar functions. Named parameters use beanquery `%(name)s` placeholders and a `params` map.

Successful table or printed directives vs errors is XOR. `QueryValue` wraps existing `guar_domain` types (`Amount`, `Position`, `Inventory`, `Account`, `BeanDate`, `Flag`, `Directive`, …) plus Dart primitives. There is no parallel amount or inventory type in this package.

`CREATE TABLE` and `INSERT` parse and fail at compile (`CREATE TABLE is not supported`, `INSERT is not supported`). Generic CSV tables are out of scope the same way.

`OPEN` / `CLOSE` / `CLEAR` on a `FROM` clause summarize the booked directives at query time. They do not change the ledger.

### Tables

Execution reads Beancount tables derived from the ledger:

| Name | Rows |
| --- | --- |
| `postings` | One row per posting (also the default when `FROM` is omitted) |
| `entries` | Every dated directive |
| `transactions` | Transactions |
| `accounts` | Accounts that were opened or closed |
| `prices` | Price directives |
| `balances` | Balance directives |
| `notes` | Note directives |
| `events` | Event directives |
| `documents` | Document directives |
| `commodities` | Commodity directives |

## Layout

```
lib/
  guar_query.dart     public API
  src/grammar.dart    petitparser BQL grammar
  src/ast.dart        Freezed statement and expression tree
  src/compile.dart    compile and execute
  src/tables.dart     ledger-backed tables
  src/value.dart      QueryValue / QueryType
test/
  parser/parser_test.dart      ports of beanquery parser_test.py
  execute/execute_test.dart    ports of beanquery query_execute_test.py
```

## Developing

Query work is fixture-driven against beanquery’s parser and execute tests. Add the Dart cases for a small group, then implement the smallest parser, compile, or execute change that turns that group green.

### Prerequisites

- [FVM](https://fvm.app/) Flutter/Dart from the repo `.fvmrc` (SDK `^3.12.0`)
- `fvm dart pub get` from the workspace root

### Commands

```sh
cd packages/guar_query

fvm dart test
fvm dart analyze --fatal-infos
fvm dart format --line-length 120 .
fvm dart run build_runner build --delete-conflicting-outputs
```

Regenerate Freezed parts after changing `lib/src/ast.dart` or `lib/src/result.dart`. Generated `*.freezed.dart` files are gitignored.

## License

GPL-3.0-only (see the repo `LICENSE`).
