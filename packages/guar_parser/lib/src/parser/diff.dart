// Structural diff of two ParsedLedgers.

import '../domain/domain.dart';

const _nowhere = BeanLocation(linenoBegin: 0, linenoEnd: 0);

LedgerDiff diffLedgers(ParsedLedger left, ParsedLedger right, {required bool considerLocations}) {
  final options = _diffOptions(left.options, right.options);
  final info = _diffInfo(left.info, right.info, considerLocations: considerLocations);
  switch ((left, right)) {
    case (
      ParsedLedgerDirectives(directives: final leftDirectives),
      ParsedLedgerDirectives(directives: final rightDirectives),
    ):
      final directivesDiff = _directiveDiff(leftDirectives, rightDirectives, considerLocations: considerLocations);
      return LedgerDiff(
        onlyInLeft: directivesDiff.onlyInLeft,
        onlyInRight: directivesDiff.onlyInRight,
        changed: directivesDiff.changed,
        options: options,
        info: info,
      );
    case (ParsedLedgerErrors(errors: final leftErrors), ParsedLedgerErrors(errors: final rightErrors)):
      final errorsDiff = _listDiff(leftErrors, rightErrors, (a, b) => _sameError(a, b, considerLocations));
      return LedgerDiff(
        errorsOnlyInLeft: errorsDiff.onlyInLeft,
        errorsOnlyInRight: errorsDiff.onlyInRight,
        options: options,
        info: info,
      );
    case (ParsedLedgerDirectives(:final directives), ParsedLedgerErrors(:final errors)):
      return LedgerDiff(onlyInLeft: directives, errorsOnlyInRight: errors, options: options, info: info);
    case (ParsedLedgerErrors(:final errors), ParsedLedgerDirectives(:final directives)):
      return LedgerDiff(errorsOnlyInLeft: errors, onlyInRight: directives, options: options, info: info);
  }
}

({List<ParsedDirective> onlyInLeft, List<ParsedDirective> onlyInRight, List<ChangedDirective> changed}) _directiveDiff(
  List<ParsedDirective> left,
  List<ParsedDirective> right, {
  required bool considerLocations,
}) {
  if (!considerLocations) {
    final lists = _listDiff(left, right, (a, b) => _withoutLocations(a) == _withoutLocations(b));
    return (onlyInLeft: lists.onlyInLeft, onlyInRight: lists.onlyInRight, changed: const []);
  }
  final used = List<bool>.filled(right.length, false);
  final onlyInLeft = <ParsedDirective>[];
  final changed = <ChangedDirective>[];
  for (final item in left) {
    var matched = false;
    for (var i = 0; i < right.length; i++) {
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
  final onlyInRight = [
    for (var i = 0; i < right.length; i++)
      if (!used[i]) right[i],
  ];
  return (onlyInLeft: onlyInLeft, onlyInRight: onlyInRight, changed: changed);
}

OptionsDiff _diffOptions(LedgerOptions left, LedgerOptions right) {
  return OptionsDiff(
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
}

InfoDiff _diffInfo(ProcessingInfo left, ProcessingInfo right, {required bool considerLocations}) {
  return InfoDiff(
    filename: considerLocations ? _change(left.filename, right.filename) : null,
    include: _listDiff(left.include, right.include, _eq),
    commodities: _listDiff(left.commodities, right.commodities, _eq),
    plugin: _listDiff(left.plugin, right.plugin, (a, b) => _samePlugin(a, b, considerLocations)),
    displayContext: _listDiff(left.displayContext.precisions, right.displayContext.precisions, _eq),
    optionSettings: _listDiff(
      left.optionSettings,
      right.optionSettings,
      (a, b) => _sameSetting(a, b, considerLocations),
    ),
  );
}

FieldChange<T>? _change<T>(T left, T right) => left == right ? null : FieldChange(left: left, right: right);

bool _eq<T>(T left, T right) => left == right;

ListDiff<T> _listDiff<T>(List<T> left, List<T> right, bool Function(T, T) same) {
  final used = List<bool>.filled(right.length, false);
  final onlyInLeft = <T>[];
  for (final item in left) {
    var found = false;
    for (var i = 0; i < right.length; i++) {
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
  return ListDiff(
    onlyInLeft: onlyInLeft,
    onlyInRight: [
      for (var i = 0; i < right.length; i++)
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

ParsedDirective _withoutLocations(ParsedDirective directive) {
  return directive.copyWith(
    location: _nowhere,
    body: switch (directive.body) {
      TransactionBody(:final value) => DirectiveBody.transaction(
        value.copyWith(postings: [for (final posting in value.postings) posting.copyWith(location: _nowhere)]),
      ),
      _ => directive.body,
    },
  );
}
