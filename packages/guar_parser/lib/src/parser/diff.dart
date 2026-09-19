// Structural diff of two ParsedLedgers.

import 'package:guar_parser/src/domain/domain.dart';

final BeanLocation _nowhere = BeanLocation(linenoBegin: 0, linenoEnd: 0);

LedgerDiff diffLedgers(ParsedLedger left, ParsedLedger right, {required bool considerLocations}) {
  final OptionsDiff options = _diffOptions(left.options, right.options);
  final InfoDiff info = _diffInfo(left.info, right.info, considerLocations: considerLocations);
  final ListDiff<ParseWarning> warningsDiff = _listDiff(
    left.warnings,
    right.warnings,
    (ParseWarning a, ParseWarning b) => _sameWarning(a, b, considerLocations),
  );
  switch ((left, right)) {
    case (
      ParsedLedgerDirectives(directives: final List<ParsedDirective> leftDirectives),
      ParsedLedgerDirectives(directives: final List<ParsedDirective> rightDirectives),
    ):
      final ({List<ChangedDirective> changed, List<ParsedDirective> onlyInLeft, List<ParsedDirective> onlyInRight})
      directivesDiff = _directiveDiff(leftDirectives, rightDirectives, considerLocations: considerLocations);
      return LedgerDiff(
        onlyInLeft: directivesDiff.onlyInLeft,
        onlyInRight: directivesDiff.onlyInRight,
        changed: directivesDiff.changed,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (
      ParsedLedgerErrors(errors: final List<ParseError> leftErrors),
      ParsedLedgerErrors(errors: final List<ParseError> rightErrors),
    ):
      final ListDiff<ParseError> errorsDiff = _listDiff(
        leftErrors,
        rightErrors,
        (ParseError a, ParseError b) => _sameError(a, b, considerLocations),
      );
      return LedgerDiff(
        errorsOnlyInLeft: errorsDiff.onlyInLeft,
        errorsOnlyInRight: errorsDiff.onlyInRight,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (
      ParsedLedgerDirectives(:final List<ParsedDirective> directives),
      ParsedLedgerErrors(:final List<ParseError> errors),
    ):
      return LedgerDiff(
        onlyInLeft: directives,
        errorsOnlyInRight: errors,
        warningsOnlyInLeft: warningsDiff.onlyInLeft,
        warningsOnlyInRight: warningsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (
      ParsedLedgerErrors(:final List<ParseError> errors),
      ParsedLedgerDirectives(:final List<ParsedDirective> directives),
    ):
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

({List<ParsedDirective> onlyInLeft, List<ParsedDirective> onlyInRight, List<ChangedDirective> changed}) _directiveDiff(
  List<ParsedDirective> left,
  List<ParsedDirective> right, {
  required bool considerLocations,
}) {
  if (!considerLocations) {
    final ListDiff<ParsedDirective> lists = _listDiff(
      left,
      right,
      (ParsedDirective a, ParsedDirective b) => _withoutLocations(a) == _withoutLocations(b),
    );
    return (onlyInLeft: lists.onlyInLeft, onlyInRight: lists.onlyInRight, changed: const <ChangedDirective>[]);
  }
  final List<bool> used = List<bool>.filled(right.length, false);
  final List<ParsedDirective> onlyInLeft = <ParsedDirective>[];
  final List<ChangedDirective> changed = <ChangedDirective>[];
  for (final ParsedDirective item in left) {
    bool matched = false;
    for (int i = 0; i < right.length; i++) {
      if (used[i] || item.location != right[i].location) {
        continue;
      }
      used[i] = true;
      matched = true;
      if (item != right[i]) {
        changed.add(ChangedDirective(left: item, right: right[i]));
      }
      break;
    }
    if (!matched) {
      onlyInLeft.add(item);
    }
  }
  final List<ParsedDirective> onlyInRight = <ParsedDirective>[
    for (int i = 0; i < right.length; i++)
      if (!used[i]) right[i],
  ];
  return (onlyInLeft: onlyInLeft, onlyInRight: onlyInRight, changed: changed);
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

InfoDiff _diffInfo(ProcessingInfo left, ProcessingInfo right, {required bool considerLocations}) => InfoDiff(
  filename: considerLocations ? _change(left.filename, right.filename) : null,
  include: _listDiff(left.include, right.include, _eq),
  commodities: _listDiff(left.commodities, right.commodities, _eq),
  plugin: _listDiff(left.plugin, right.plugin, (Plugin a, Plugin b) => _samePlugin(a, b, considerLocations)),
  displayContext: _listDiff(left.displayContext.precisions, right.displayContext.precisions, _eq),
  optionSettings: _listDiff(
    left.optionSettings,
    right.optionSettings,
    (OptionSetting a, OptionSetting b) => _sameSetting(a, b, considerLocations),
  ),
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

bool _samePlugin(Plugin left, Plugin right, bool considerLocations) {
  if (left.name != right.name || left.config != right.config) {
    return false;
  }
  return !considerLocations || left.location == right.location;
}

bool _sameSetting(OptionSetting left, OptionSetting right, bool considerLocations) {
  if (left.key != right.key || left.value != right.value) {
    return false;
  }
  return !considerLocations || left.location == right.location;
}

bool _sameError(ParseError left, ParseError right, bool considerLocations) {
  if (left.message != right.message) {
    return false;
  }
  return !considerLocations || left.location == right.location;
}

bool _sameWarning(ParseWarning left, ParseWarning right, bool considerLocations) {
  if (left.message != right.message) {
    return false;
  }
  return !considerLocations || left.location == right.location;
}

ParsedDirective _withoutLocations(ParsedDirective directive) => directive.copyWith(
  location: _nowhere,
  body: switch (directive.body) {
    TransactionBody(:final ParsedTransaction value) => DirectiveBody.transaction(
      value.copyWith(
        postings: <ParsedPosting>[
          for (final ParsedPosting posting in value.postings) posting.copyWith(location: _nowhere),
        ],
      ),
    ),
    _ => directive.body,
  },
);
