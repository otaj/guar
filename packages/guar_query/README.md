# guar_query

Beancount Query Language (BQL) for booked guar ledgers.

This package parses beanquery syntax and runs `SELECT` / `JOURNAL` / `BALANCES` /
`PRINT` against a `guar_domain` `Ledger`. It does not parse Beancount source or
run booking — that belongs to `guar_parser` and `guar_book`.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                                          │
                                          ▼
                                     guar_query  ──►  QueryResult
```

Successful table / printed directives vs errors is XOR. Cell values wrap
existing `guar_domain` types (plus Dart primitives). `CREATE TABLE` and
`INSERT` parse and fail at compile.

Developed against beanquery parser and execute tests.
