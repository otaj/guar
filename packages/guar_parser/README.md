# guar_parser

Beancount parser for guar. It turns ledger source into Freezed domain models.

This package is unpublished (`publish_to: none`) and developed against lima-derived golden fixtures. Booking, interpolation, and plugin execution are out of scope; that work belongs to a later `ProcessedLedger` layer.

## Architecture

```
Beancount source
      │
      ▼
BeancountParser  ──►  ParsedLedger   (XOR: directives or errors)
      │                      │
      │                      ▼
      │              lib/src/domain/   public shape
      │
      └── petitparser grammar in lib/src/parser/
```

- **Domain** (`lib/src/domain/`) is the parser's public type system. Align types with Beancount language meaning, not protobuf field numbers.
- **Parser** (`lib/src/parser/`) is a line-oriented document parser. Petitparser fragments in `tokens.dart` parse dates, amounts, expressions, and similar; `grammar.dart` walks the file, applies `include` / `option` / `plugin` / push-pop stacks, and emits directives.
- **`protobean` is test-only.** `lib/` must not import it. Golden tests map domain → proto in `test/mapping/domain_to_proto.dart`.

Successful parse vs errors is XOR, matching protobean `ParsedLedger`. `pushtag` / `poptag` / `pushmeta` / `popmeta` mutate parse state and are not directives.

On success, dated directives are sorted by date, then type, then source line.

## Public API

```dart
import 'package:guar_parser/guar_parser.dart';

final ledger = const BeancountParser().parse(
  source,
  filename: 'ledger.beancount',
);

switch (ledger) {
  case ParsedLedgerDirectives(:final directives, :final options, :final info):
    for (final directive in directives) {
      // directive.date, .meta, .body (TransactionBody, OpenBody, …)
    }
  case ParsedLedgerErrors(:final errors):
    for (final error in errors) {
      // error.message, error.location
    }
}
```

`filename` is used for locations and as the base path for relative `include`s. `BeancountParser.parse` reads includes from the filesystem.

To add or replace a region without reparsing the rest of the file, pass the already-parsed ledger, the snippet, and the inclusive 1-based span it occupies (`endLine < startLine` inserts before `startLine`):

```dart
final updated = const BeancountParser().splice(
  ledger,
  snippet,
  filename: 'ledger.beancount',
  startLine: 10,
  endLine: 12,
);
```

Constructs in that filename whose locations overlap `[startLine, endLine]` are dropped and replaced by whatever the snippet parses to (directives, options, plugins). Later line numbers in the same file shift if the snippet is a different length. A failing snippet yields `ParsedLedger.errors` (XOR).

Notable domain choices:

| Type | Notes |
| --- | --- |
| `BeanDate` | Civil y/m/d, not `DateTime` |
| `BeanNumber` | `verbatim` as written plus resolved `Decimal` |
| `Flag` | Sealed: special (`*`, `!`, …) or letter |
| `DirectiveBody` | Sealed union of dated directive kinds |
| `IncompleteAmount` / `ParsedCost` / `ParsedPrice` | Pre-booking posting shape |

## Layout

```
lib/
  guar_parser.dart          public exports
  src/domain/               Freezed models
  src/parser/
    beancount_parser.dart   entry point
    grammar.dart            document walk
    tokens.dart             petitparser fragments
    include.dart            path/glob/duplicate include
test/
  cases/                    lima fixtures (.beancount + .txtpb)
  cases_unsupported/        lima-unsupported fixtures
  harness/
    golden_test.dart        discovers pairs, compares via protobean
    unmigrated_skips.yaml   explicit skip list
  mapping/domain_to_proto.dart
```

Workspace-level `tool/txtpb_to_pb.py` loads a `.txtpb` golden into tagged protobuf bytes for the Dart harness. Tests must be run from this package directory so fixture paths resolve.

## Developing

### Prerequisites

- [FVM](https://fvm.app/) Flutter/Dart from `.fvmrc` (SDK `^3.12.0`)
- [uv](https://docs.astral.sh/uv/) (Python ≥ 3.10) for `tool/txtpb_to_pb.py`
- `fvm dart pub get` from the workspace root or this package

### Commands

```sh
cd packages/guar_parser

fvm dart test
fvm dart test --name ParserEntryTypes.Close
fvm dart analyze --fatal-infos
fvm dart format --line-length 120 .
fvm dart run build_runner build --delete-conflicting-outputs
```

Regenerate Freezed parts after changing `lib/src/domain/*.dart`. Generated `*.freezed.dart` files are gitignored.

### Fixture-driven TDD

Do not implement a construct before a golden expects it. Typical slice:

1. Rewrite the fixture `.txtpb` to flat protobean `ParsedDirectives` or `Errors` (not `ParsedLedger`, unless the case is about `options` / `info`).
2. Keep original `#` comments from lima (EOF notes, etc.). Prefer lima-like compact layout (`date { year: y month: m day: d }`, inline leaf messages). Omit `location`; the harness clears it on both sides.
3. If the lima file contains `# ANOMALY`, leave it on `unmigrated` until the anomaly is resolved. After accepting the same behavior, keep the lima comment and add a `# guar:` note.
4. Remove that stem from `test/harness/unmigrated_skips.yaml` in the same change.
5. Run the golden: prototxt load must succeed; the parser comparison may fail.
6. Implement the smallest domain/parser/mapper change that turns it green.
7. Commit that slice before starting the next group.

Parse-error goldens should use lima `found '…' expected …` wording when the parser can emit that shape.

Example directive golden (`ParserEntryTypes.Close`):

```
directives {
  date { year: 2013 month: 5 day: 18 }
  close { account { name: "Assets:US:BestBank:Checking" } }
}
```

Example error golden:

```
errors {
  message: "found 'open' expected something else"
}
```

Cases that assert options or processing info use a `ParsedLedger` prototxt (top-level `options` / `info` fields). The loader in `tool/txtpb_to_pb.py` picks the message type from those fields.

### Skip list

Only skip via `test/harness/unmigrated_skips.yaml`:

- `unmigrated`: stem whose `.txtpb` is still lima `ParsedLedger`, not yet rewritten
- `product`: stem we do not intend to implement, with an explicit reason

A prototxt load failure is a test failure, never an implicit skip. Ask before adding a product skip that drops a language feature.

### Style

- One short top-of-file comment stating why the file exists. No other comments, dartdocs, or TODOs unless the logic is non-obvious (indent/lexer tricks, skip-list semantics, number verbatim vs resolved, protobean XOR).
- Leave generated Freezed files alone.
- Conventional Commits; one concern per commit. Typical slice is `test:` then `feat(parser):`, or a single commit if the change is tiny.

## License

GPL-3.0-only (see the repo `LICENSE`). Fixtures in `test/cases/` come from [beancount-parser-lima](https://github.com/tesujimath/beancount-parser-lima) (parser MIT/Apache-2.0; Beancount protobuf goldens historically GPLv2).
