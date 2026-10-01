# AGENTS.md

## Project

Guar is a Beancount plain-text accounting app for Android (Flutter). It is a Dart/Flutter pub workspace with six packages under `packages/`. Most code is AI-generated.

## Commands

All Flutter/Dart commands must go through FVM (pinned in `.fvmrc`). Use `scripts/run_fvm.sh` to wrap FVM safely (it unsets `GIT_DIR`/`GIT_WORK_TREE` that pre-commit exports, which would corrupt the shared SDK cache):

```sh
# From repo root
scripts/run_fvm.sh dart pub get
scripts/run_fvm.sh dart analyze --fatal-warnings --fatal-infos
scripts/run_fvm.sh dart format --set-exit-if-changed .
scripts/run_fvm.sh dart test --directory packages/guar_parser
scripts/run_fvm.sh flutter test --directory packages/guar
```

Or use `fvm` directly if it is on PATH (the wrapper falls back to PATH in CI).

### Code generation

After changing Freezed models in `guar_parser`, `guar_domain`, or `guar_query`, regenerate:

```sh
scripts/generate.sh
```

Generated `*.freezed.dart` files are gitignored — never edit or commit them.

### Running tests

Tests must be run from the package directory (fixture paths are relative). Use `--directory` from the repo root:

```sh
scripts/run_fvm.sh dart test --directory packages/guar_parser
scripts/run_fvm.sh dart test --directory packages/guar_parser --name ParserEntryTypes.Close
```

`./scripts/test.sh` runs all workspace packages from the root.

### Pre-commit hooks

Install both hook stages:

```sh
pre-commit install --hook-type pre-commit --hook-type commit-msg
```

Hooks enforce: dart format, dart analyze (`--fatal-warnings --fatal-infos`), ruff (Python), shellcheck, conventional commits, pub outdated check, Kotlin detekt, and the pubspec versionCode formula.

## Architecture

```
guar_parser  ──►  ParsedLedger
                      │
                      ▼
                   guar_book   ──►  guar_domain Ledger
                                       │
                                       ▼
                                  guar_query
                                       │
                                       ▼
                                     guar   (Flutter Android app)
```

- `guar_parser` — Beancount source → Freezed domain models (petitparser grammar)
- `guar_domain` — Booked ledger types (Freezed)
- `guar_book` — Booking/validation pipeline (parser + plugins → domain)
- `guar_plugins` — Stock Beancount and reds plugins
- `guar_query` — BQL query engine over booked ledgers
- `guar` — Flutter Android app (currently an empty shell)

Dependency direction is strictly downward. `guar_domain` must not import `guar_parser` or `protobean`. `guar_book` and `guar_query` must not import `protobean` from `lib/`.

## Constraints

- **No Google Play services.** `scripts/check_no_google_libs.sh` fails the build if GMS, Firebase, ML Kit, or Play libraries appear in the Gradle classpath or APK. Open-source Google Maven artifacts (Tink, Gson, annotations) are allowed.
- **Version code formula.** `packages/guar/pubspec.yaml` version must be `X.Y.Z+N` where `N = 10000*major + 100*minor + patch`. The `+N` is the pre-ABI Android versionCode; `android/app/build.gradle.kts` packs the ABI as `10*N + abi`. Enforced by pre-commit.
- **Line length 120.** Dart format uses `--line-length 120`. The 80-char lint is disabled.
- **Conventional Commits** with one concern per commit. Enforced by pre-commit.
- **Minimal comments.** One short top-of-file comment stating why the file exists. No other comments, dartdocs, or TODOs unless logic is non-obvious. See `.cursor/rules/comments.mdc`.

## TDD workflow (parser & query)

Parser and query work is fixture-driven. Do not implement a construct before a golden expects it.

### Parser (`guar_parser`)

1. Rewrite the fixture `.txtpb` to flat protobean `ParsedDirectives` or `Errors` (not `ParsedLedger`, unless testing `options`/`info`).
2. Keep original `#` comments from lima. If the file has `# ANOMALY`, leave it on `unmigrated`.
3. Remove the stem from `test/harness/unmigrated_skips.yaml`.
4. Run the golden — prototxt load must succeed; parser comparison may fail.
5. Implement the smallest domain/parser/mapper change that turns it green.
6. Commit before starting the next group.

Goldens omit `location` (the harness clears it on both sides). Use lima-like compact layout. Parse-error goldens should use lima `found '…' expected …` wording.

### Query (`guar_query`)

Port a small group from beanquery's `parser_test.py` or `query_execute_test.py`, add Dart tests, implement the smallest change to make them green, commit.

## Release builds

`scripts/fdroid_build.sh` builds one ABI at a time for reproducible APKs (GitHub Releases and F-Droid must match byte-for-byte):

```sh
./scripts/fdroid_build.sh android-arm64
```

Requires `flutter` on PATH and uses `$ROOT/.pub-cache` for reproducibility.
