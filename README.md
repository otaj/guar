# Guar

Beancount for Android.

Guar is a plain-text accounting app for [Beancount](https://beancount.github.io/) ledgers. It is Android-only (`dev.otaj.guar`), stays off Google Play services, and is built so releases can be reproduced for F-Droid.

**Notice:** Most of the code in this repository is AI-generated.

## Name origin

Guar is a bean. Its leaves are arrow-shaped, if you squint hard enough.

## The app

The Android app lives in [`packages/guar`](packages/guar). Version codes, the per-ABI split, and how to build are in [its README](packages/guar/README.md).

Parsing, booking, and queries are libraries the app calls. The screen itself is still an empty shell.

## Libraries

- [`guar_parser`](packages/guar_parser) parses Beancount source.
- [`guar_domain`](packages/guar_domain) holds the booked ledger types.
- [`guar_book`](packages/guar_book) books and validates a parsed ledger.
- [`guar_plugins`](packages/guar_plugins) runs the stock Beancount and reds plugins.
- [`guar_query`](packages/guar_query) runs Beancount Query Language against a booked ledger.

## License

GPL-3.0-only. See [LICENSE](LICENSE).
