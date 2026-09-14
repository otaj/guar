# guar_domain

Booked Beancount domain types for guar (Freezed).

This package holds complete amounts, resolved lots, inventories, directives, and
the historical price map after booking and interpolation. It does not parse
source or run the booking algorithm — that belongs to `guar_parser` and a later
`guar_book` package.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain (Ledger, Inventory, PriceMap)
```

Developed against beancount.core unit tests and limabean inventory goldens.
