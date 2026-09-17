# guar_plugins

Stock Beancount and reds plugins that run after booking.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                      │
                      ▼
                 guar_plugins   (beancount.plugins.* / beancount_reds_plugins.*)
```

`Book()` registers these by default under their original Python module names. Pass `plugins:` to override. This package does not parse source or run booking — that belongs to `guar_parser` and `guar_book`.
