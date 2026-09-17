# guar_book

Books and validates a `guar_parser` `ParsedLedger` into `guar_domain` types.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
```

Pipeline: default unset options → book/interpolate → documents/pad/balance → user plugins → validations. Successful result vs errors is XOR (plugin and validation errors drop directives). Stock Beancount plugins are registered by default under `beancount.plugins.*` names (including meta plugins `auto` and `pedantic`); reds plugins under their original `beancount_reds_plugins.*` module names. Pass `plugins:` to override.

`Book.splice` parses a snippet into an existing `ParsedLedger` (same span rules as `BeancountParser.splice`) and re-runs the full booking pipeline on the result:

```dart
final updated = Book().splice(
  parsed,
  snippet,
  filename: 'ledger.beancount',
  startLine: 10,
  endLine: 12,
);
```

`Book.diff` compares two booked `Ledger`s by content. Source locations (and `info.filename`) are ignored, so the same construct on different lines or files matches. `onlyInLeft` / `onlyInRight` are directives or errors present on one side only; options and processing info are compared field-by-field.

```dart
final diff = Book().diff(left, right);
```
