# guar_book

Books and validates a `guar_parser` `ParsedLedger` into `guar_domain` types.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
```

Pipeline: default unset options → book/interpolate → documents/pad/balance → user plugins → validations. Successful result vs errors is XOR. Stock Beancount plugins are not shipped yet; callers inject plugins by name.

`Book.splice` parses a snippet into an existing `ParsedLedger` (same span rules as `BeancountParser.splice`) and re-runs the full booking pipeline on the result:

```dart
final updated = const Book().splice(
  parsed,
  snippet,
  filename: 'ledger.beancount',
  startLine: 10,
  endLine: 12,
);
```

`Book.diff` compares two booked `Ledger`s by content. Source locations (and `info.filename`) are ignored, so the same construct on different lines or files matches. `onlyInLeft` / `onlyInRight` are directives or errors present on one side only; options and processing info are compared field-by-field.

```dart
final diff = const Book().diff(left, right);
```
