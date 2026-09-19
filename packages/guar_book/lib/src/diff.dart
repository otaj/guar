// Structural diff of two booked Ledgers (locations ignored).

import 'package:guar_domain/guar_domain.dart';

final BeanLocation _nowhere = BeanLocation(linenoBegin: 0, linenoEnd: 0);

LedgerDiff diffLedgers(Ledger left, Ledger right) {
  final OptionsDiff options = _diffOptions(left.options, right.options);
  final InfoDiff info = _diffInfo(left.info, right.info);
  final ListDiff<ProcessingWarning> warningsDiff = _listDiff(
    left.warnings,
    right.warnings,
    (ProcessingWarning a, ProcessingWarning b) => a.message == b.message,
  );
  switch ((left, right)) {
    case (
      LedgerDirectives(directives: final List<Directive> leftDirectives),
      LedgerDirectives(directives: final List<Directive> rightDirectives),
    ):
      final ListDiff<Directive> directivesDiff = _listDiff(
        leftDirectives,
        rightDirectives,
        (Directive a, Directive b) => _withoutLocations(a) == _withoutLocations(b),
      );
      return LedgerDiff(
        onlyInLeft: directivesDiff.onlyInLeft,
        onlyInRight: directivesDiff.onlyInRight,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (
      LedgerErrors(errors: final List<ProcessingError> leftErrors),
      LedgerErrors(errors: final List<ProcessingError> rightErrors),
    ):
      final ListDiff<ProcessingError> errorsDiff = _listDiff(
        leftErrors,
        rightErrors,
        (ProcessingError a, ProcessingError b) => a.message == b.message,
      );
      return LedgerDiff(
        errorsOnlyInLeft: errorsDiff.onlyInLeft,
        errorsOnlyInRight: errorsDiff.onlyInRight,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (LedgerDirectives(:final List<Directive> directives), LedgerErrors(:final List<ProcessingError> errors)):
      return LedgerDiff(
        onlyInLeft: directives,
        errorsOnlyInRight: errors,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (LedgerErrors(:final List<ProcessingError> errors), LedgerDirectives(:final List<Directive> directives)):
      return LedgerDiff(
        errorsOnlyInLeft: errors,
        onlyInRight: directives,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
  }
}

OptionsDiff _diffOptions(LedgerOptions left, LedgerOptions right) => OptionsDiff(
  accountPrefixes: _change(left.accountPrefixes, right.accountPrefixes),
  title: _change(left.title, right.title),
  accountPreviousBalances: _change(left.accountPreviousBalances, right.accountPreviousBalances),
  accountPreviousEarnings: _change(left.accountPreviousEarnings, right.accountPreviousEarnings),
  accountPreviousConversions: _change(left.accountPreviousConversions, right.accountPreviousConversions),
  accountCurrentEarnings: _change(left.accountCurrentEarnings, right.accountCurrentEarnings),
  accountCurrentConversions: _change(left.accountCurrentConversions, right.accountCurrentConversions),
  accountUnrealizedGains: _change(left.accountUnrealizedGains, right.accountUnrealizedGains),
  accountRounding: _change(left.accountRounding, right.accountRounding),
  conversionCurrency: _change(left.conversionCurrency, right.conversionCurrency),
  displayPrecision: _listDiff(left.displayPrecision, right.displayPrecision, _eq),
  inferredToleranceDefault: _listDiff(left.inferredToleranceDefault, right.inferredToleranceDefault, _eq),
  inferredToleranceMultiplier: _change(left.inferredToleranceMultiplier, right.inferredToleranceMultiplier),
  toleranceMultiplier: _change(left.toleranceMultiplier, right.toleranceMultiplier),
  inferToleranceFromCost: _change(left.inferToleranceFromCost, right.inferToleranceFromCost),
  documents: _listDiff(left.documents, right.documents, _eq),
  operatingCurrency: _listDiff(left.operatingCurrency, right.operatingCurrency, _eq),
  renderCommas: _change(left.renderCommas, right.renderCommas),
  pluginProcessingMode: _change(left.pluginProcessingMode, right.pluginProcessingMode),
  longStringMaxlines: _change(left.longStringMaxlines, right.longStringMaxlines),
  bookingMethod: _change(left.bookingMethod, right.bookingMethod),
  usePreciseInterpolation: _change(left.usePreciseInterpolation, right.usePreciseInterpolation),
  insertPythonpath: _change(left.insertPythonpath, right.insertPythonpath),
  allowPipeSeparator: _change(left.allowPipeSeparator, right.allowPipeSeparator),
  allowDeprecatedNoneForTagsAndLinks: _change(
    left.allowDeprecatedNoneForTagsAndLinks,
    right.allowDeprecatedNoneForTagsAndLinks,
  ),
);

InfoDiff _diffInfo(ProcessingInfo left, ProcessingInfo right) => InfoDiff(
  include: _listDiff(left.include, right.include, _eq),
  commodities: _listDiff(left.commodities, right.commodities, _eq),
  plugin: _listDiff(left.plugin, right.plugin, _samePlugin),
  displayContext: _listDiff(left.displayContext.precisions, right.displayContext.precisions, _eq),
  optionSettings: _listDiff(left.optionSettings, right.optionSettings, _sameSetting),
);

FieldChange<T>? _change<T>(T left, T right) => left == right ? null : FieldChange<T>(left: left, right: right);

bool _eq<T>(T left, T right) => left == right;

ListDiff<T> _listDiff<T>(List<T> left, List<T> right, bool Function(T left, T right) same) {
  final List<bool> used = List<bool>.filled(right.length, false);
  final List<T> onlyInLeft = <T>[];
  for (final T item in left) {
    bool found = false;
    for (int i = 0; i < right.length; i++) {
      if (!used[i] && same(item, right[i])) {
        used[i] = true;
        found = true;
        break;
      }
    }
    if (!found) {
      onlyInLeft.add(item);
    }
  }
  return ListDiff<T>(
    onlyInLeft: onlyInLeft,
    onlyInRight: <T>[
      for (int i = 0; i < right.length; i++)
        if (!used[i]) right[i],
    ],
  );
}

bool _samePlugin(Plugin left, Plugin right) => left.name == right.name && left.config == right.config;

bool _sameSetting(OptionSetting left, OptionSetting right) => left.key == right.key && left.value == right.value;

Origin _clearedOrigin(Origin origin) => switch (origin) {
  SourceOrigin() => Origin.source(_nowhere),
  GeneratedOrigin() => const Origin.generated(),
};

Directive _withoutLocations(Directive directive) => directive.copyWith(
  origin: _clearedOrigin(directive.origin),
  body: switch (directive.body) {
    TransactionBody(:final Transaction value) => DirectiveBody.transaction(
      value.copyWith(
        origin: _clearedOrigin(value.origin),
        postings: <Posting>[
          for (final Posting posting in value.postings) posting.copyWith(origin: _clearedOrigin(posting.origin)),
        ],
      ),
    ),
    _ => directive.body,
  },
);
