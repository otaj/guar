# guar_book

Books and validates a `guar_parser` `ParsedLedger` into a `guar_domain` `Ledger`.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                 (+ guar_plugins)
```

Pipeline:

1. Fill unset options from Beancount defaults.
2. Book and interpolate postings.
3. Apply documents and pad (skipped when `plugin_processing_mode` is `raw`).
4. Run each `plugin` directive through the registered `BookPlugin` map.
5. Check balances and the remaining validations (also skipped in `raw` mode).

A processing error yields `Ledger.errors` and drops directives. Parse warnings are forwarded and do not fail booking. Pass `recover: true` to keep the directives alongside the errors.

`Book()` starts from `guar_plugins` `defaultPlugins` (`beancount.plugins.*` and `beancount_reds_plugins.*`, including the meta plugins `auto` and `pedantic`). Entries in `plugins:` replace the same module name.

```dart
import 'package:guar_book/guar_book.dart';

final booked = Book().process(parsed);

final recovered = Book().process(parsed, recover: true);
```

`Book.splice` reuses parser span splicing, then rebooks the whole ledger:

```dart
final updated = Book().splice(
  parsed,
  snippet,
  filename: 'ledger.beancount',
  startLine: 10,
  endLine: 12,
);
```

`Book.diff` compares two booked ledgers by content. Source locations and `info.filename` are ignored, so the same construct on different lines or files matches. `onlyInLeft` / `onlyInRight` are directives or errors present on one side only. Options and processing info are compared field by field.

```dart
final diff = Book().diff(left, right);
```

`inventoryFromLedger` / `inventoryFromDirectives` replay booked transaction postings into a `LedgerInventory`.

## Layout

```
lib/
  guar_book.dart           public API (Book, inventory helpers, option mapping)
  src/book.dart            pipeline
  src/booking/             interpolation and lot booking
  src/stages/              documents, pad, balance
  src/validate/            post-plugin checks
test/
  cases/                   booked golden fixtures (.beancount + .txtpb)
  harness/golden_test.dart
```

`lib/` does not import protobean. Golden tests map a booked `Ledger` onto protobean `Processed*` messages.

## Developing

### Prerequisites

- [FVM](https://fvm.app/) Flutter/Dart from the repo `.fvmrc` (SDK `^3.12.0`)
- `fvm dart pub get` from the workspace root

### Commands

```sh
cd packages/guar_book

fvm dart test
fvm dart analyze --fatal-infos
fvm dart format --line-length 120 .
```

Run tests from this package directory so fixture paths resolve.

## License

GPL-3.0-only (see the repo `LICENSE`).
