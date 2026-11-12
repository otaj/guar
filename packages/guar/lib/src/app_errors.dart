// Maps engine-level errors to localized text at the UI boundary.

import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/ledger_engine.dart';
import 'package:guar/src/ledger_option_draft.dart';
import 'package:guar/src/ledger_session.dart';

String? sessionMessage(LedgerSession session, GuarLocalizations l10n) => switch (session.failure) {
  null => session.error,
  final GuarFailure failure => failureText(l10n, failure),
};

String failureText(GuarLocalizations l10n, GuarFailure failure) => switch (failure) {
  GuarFailure.couldNotWriteIncluded => l10n.couldNotWriteIncluded,
  GuarFailure.couldNotSaveTransaction => l10n.couldNotSaveTransaction,
  GuarFailure.couldNotUseFile => l10n.couldNotUseFile,
};

// Append and validation errors come back from the ledger engine in English.
String appendErrorText(GuarLocalizations l10n, String error) =>
    error == couldNotReadTarget ? l10n.couldNotReadTarget : error;

String optionErrorText(GuarLocalizations l10n, OptionError error) => switch (error) {
  OptionError.invalidAccountName => l10n.errInvalidAccountName,
  OptionError.invalidCurrencyCode => l10n.errInvalidCurrencyCode,
  OptionError.wholeNumberZeroOrGreater => l10n.errWholeNumberZeroOrGreater,
  OptionError.enterNumber => l10n.errEnterNumber,
  OptionError.quotesNotAllowed => l10n.errQuotesNotAllowed,
};
