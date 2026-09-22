# guar_domain

Booked Beancount types for guar (Freezed).

This package holds the ledger after booking and interpolation: complete amounts, resolved lots, inventories, directives, options, and the historical price map. Parsing source belongs to `guar_parser`. Running the booking pipeline belongs to `guar_book`.

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                      │
                      ▼
                 guar_plugins
```

`lib/` depends only on this package's own code. Tests may construct values directly.

## Public API

```dart
import 'package:guar_domain/guar_domain.dart';

switch (ledger) {
  case LedgerDirectives(:final directives, :final options, :final warnings):
    for (final directive in directives) {
      // directive.date, .meta, .body, .origin
    }
  case LedgerErrors(:final errors):
    for (final error in errors) {
      // error.message, error.location
    }
}
```

Successful directives vs errors is XOR, matching protobean `ProcessedLedger`. `Ledger.directives` may still carry a non-empty `errors` list when booking was asked to recover. Non-fatal `warnings` sit on both variants.

Factories reject invalid shapes at construction: calendar dates, account / currency / tag / link names, letter flags, and location line ranges.

| Type | Notes |
| --- | --- |
| `BeanDate` | Civil y/m/d |
| `Amount` | Complete `Decimal` plus currency and scale |
| `Cost` | Resolved per-unit cost, including the lot date |
| `Position` / `Inventory` | Units at an optional cost; strict lot matching |
| `LedgerInventory` | Positions rolled up by account |
| `PriceMap` | Historical prices built from booked `price` directives |
| `Flag` | Sealed: special (`*`, `!`, …) or letter |
| `DirectiveBody` | Sealed union of dated directive kinds |
| `Origin` | `source` (a `BeanLocation`) or `generated` |
| `Meta` / `MetaValue` | Sealed metadata values |
| `LedgerDiff` | Structural comparison of two booked ledgers |

`Directive` stores a content hash of its date and body. `BookingMethod` is the account booking policy (`strict`, `fifo`, `lifo`, `hifo`, `average`, `none`, …).

## Layout

```
lib/
  guar_domain.dart     public barrel
  src/                 Freezed models (amount, inventory, directive, ledger, …)
test/                  unit tests ported from beancount.core
```

## Developing

### Prerequisites

- [FVM](https://fvm.app/) Flutter/Dart from the repo `.fvmrc` (SDK `^3.12.0`)
- `fvm dart pub get` from the workspace root

### Commands

```sh
cd packages/guar_domain

fvm dart test
fvm dart analyze --fatal-infos
fvm dart format --line-length 120 .
fvm dart run build_runner build --delete-conflicting-outputs
```

Regenerate Freezed parts after changing a model in `lib/src/`. Generated `*.freezed.dart` files are gitignored.

## License

GPL-3.0-only (see the repo `LICENSE`).
