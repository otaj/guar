# guar

Android app for Beancount ledgers.

Application id and namespace are `dev.otaj.guar`. The UI is Flutter and ships for Android only. Parse, book, and query live in `guar_parser`, `guar_book`, and `guar_query`. This package calls those libraries when a screen needs them.

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
                                        guar   (this app)
```

The current UI is an empty Material shell (`lib/main.dart`).

## Android

`pubspec.yaml` `version` is `versionName+versionCode`, for example `0.0.1+1`.

- `versionName` is `X.Y.Z`. Release tags are `vX.Y.Z`.
- The `+N` build number is the pre-ABI `versionCode` (`10000 * major + 100 * minor + patch`).
- `android/app/build.gradle.kts` packs the ABI: `10 * N + abi`, with `1` = `armeabi-v7a`, `2` = `arm64-v8a`, `3` = `x86_64`. `v0.0.1+1` therefore publishes version codes 11, 12, and 13.

Release APKs are split per ABI. `scripts/fdroid_build.sh` builds one ABI at a time so GitHub Releases and F-Droid can match byte for byte:

```sh
./scripts/fdroid_build.sh android-arm64
```

The app stays off Google Play services. `scripts/check_no_google_libs.sh` fails the build if the Gradle classpath resolves GMS, Firebase, ML Kit, or Play libraries, and if an APK carries Play's dependency-metadata signing block. Open-source Google Maven artifacts (Tink, Gson, annotations) are allowed.

## Developing

### Prerequisites

- [FVM](https://fvm.app/) Flutter from the repo `.fvmrc` (SDK `^3.12.0`)
- Android SDK, Java 17
- `fvm dart pub get` from the workspace root

### Commands

```sh
cd packages/guar

fvm flutter test
fvm flutter analyze --fatal-infos
fvm dart format --line-length 120 .
```

From the repo root, `./scripts/test.sh` runs `flutter test` here and `dart test` in every other workspace package.

## License

GPL-3.0-only (see the repo `LICENSE`).
