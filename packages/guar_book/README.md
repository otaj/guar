# guar_book

Books and validates a `guar_parser` `ParsedLedger` into `guar_domain` types.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
```

Pipeline: default unset options → book/interpolate → documents/pad/balance → user plugins → validations. Successful result vs errors is XOR. Stock Beancount plugins are not shipped yet; callers inject plugins by name.
