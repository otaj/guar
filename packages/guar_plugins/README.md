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

`Book()` registers `defaultPlugins` under the original Python module names. Pass `plugins:` on `Book` to replace a name. This package rewrites or validates an already booked directive list. Parsing source belongs to `guar_parser`. Booking and interpolation belong to `guar_book`.

`lib/` depends on `guar_domain` only. Tests parse and book fixtures through `guar_parser` and `guar_book`.

## Plugin hook

```dart
import 'package:guar_plugins/guar_plugins.dart';

final BookPlugin echo = (directives, options, info, config) {
  return (directives: directives, errors: const <ProcessingError>[]);
};
```

`BookPlugin` receives the current directive list, booked options, processing info, and the optional plugin config string. It returns the next directive list plus any errors. `combinePlugins` runs several hooks in order; `auto` and `pedantic` are built that way.

`stockPlugins` and `redsPlugins` are the two halves of `defaultPlugins`.

## Stock (`beancount.plugins.*`)

| Module | Behavior |
| --- | --- |
| `auto` | `auto_accounts`, then `implicit_prices` |
| `auto_accounts` | Insert `open` for accounts first used without one |
| `check_average_cost` | Keep reducing legs of `NONE`-booked accounts near the running average cost |
| `check_closing` | Expand `closing: TRUE` metadata into a zero balance assertion |
| `check_commodity` | Require a `commodity` directive for every commodity in use |
| `check_drained` | Assert a zero balance the day after a balance-sheet account closes |
| `close_tree` | Close still-open descendants when an account tree is closed |
| `coherent_cost` | Reject a commodity posted both at cost and without cost |
| `commodity_attr` | Require configured metadata on `commodity` directives |
| `currency_accounts` | Neutralize conversions into per-currency trading accounts |
| `implicit_prices` | Synthesize `price` directives from posting prices and non-reducing costs |
| `leafonly` | Reject postings on accounts that have children |
| `noduplicates` | Reject two identical directives (metadata excluded) |
| `nounused` | Report accounts that are opened and never referenced again |
| `onecommodity` | Restrict each account to one units commodity and one cost commodity |
| `pedantic` | The strict stock validators, in one plugin |
| `sellgains` | Cross-check priced lot sales against the non-income proceeds |
| `unique_prices` | Reject more than one price per date and currency pair |

## Reds (`beancount_reds_plugins.*`)

| Module | Behavior |
| --- | --- |
| `autoclose_tree.autoclose_tree` | Same tree-close as stock `close_tree` |
| `box_accrual.box_accrual` | Prorate box-spread capital losses across calendar years |
| `capital_gains_classifier.gain_loss` | Split capital-gains postings into gains and losses accounts |
| `capital_gains_classifier.long_short` | Rebook gains by IRS short-term and long-term holding period |
| `daf.daf_mirror` | Mirror DAF asset transactions onto the matching liability accounts |
| `effective_date.effective_date` | Split postings onto per-posting effective dates via holding accounts |
| `opengroup.opengroup` | Insert open/close sets from `opengroup_*` metadata |
| `rename_accounts.rename_accounts` | Rename accounts by regex |
| `zerosum.zerosum` | Match zerosum posting pairs and move them to a target account |

## Layout

```
lib/
  guar_plugins.dart    BookPlugin, defaultPlugins, stockPlugins, redsPlugins
  src/                 stock plugins
  src/reds/            reds plugins
test/plugins/          one test file per plugin
```

## Developing

### Prerequisites

- [FVM](https://fvm.app/) Flutter/Dart from the repo `.fvmrc` (SDK `^3.12.0`)
- `fvm dart pub get` from the workspace root

### Commands

```sh
cd packages/guar_plugins

fvm dart test
fvm dart analyze --fatal-infos
fvm dart format --line-length 120 .
```

## License

GPL-3.0-only (see the repo `LICENSE`).
