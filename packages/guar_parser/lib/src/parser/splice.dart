// Merges a parsed snippet into an existing ledger by source span.

import 'package:guar_parser/src/domain/domain.dart';
import 'package:guar_parser/src/parser/grammar.dart';
import 'package:guar_parser/src/parser/include.dart';
import 'package:guar_parser/src/parser/observation.dart';
import 'package:guar_parser/src/parser/option_apply.dart';

ParsedLedger spliceLedger(
  ParsedLedger ledger,
  String snippet, {
  required String filename,
  required int startLine,
  required int endLine,
}) {
  final int oldEnd = endLine < startLine ? startLine - 1 : endLine;
  final int snippetLines = _snippetLineCount(snippet);
  final int delta = snippetLines - (oldEnd >= startLine ? oldEnd - startLine + 1 : 0);
  final ParsedLedger parsed = BeancountGrammar(
    filename: filename,
    firstLine: startLine,
    includes: IncludeController.io(),
  ).parse(snippet, initialOptions: ledger.options, honorOptions: filename == (ledger.info.filename ?? ''));
  return switch ((ledger, parsed)) {
    (_, ParsedLedgerErrors(:final List<ParseError> errors, :final ProcessingInfo info)) => ParsedLedger.errors(
      errors: <ParseError>[..._keptErrors(ledger, filename, startLine, oldEnd, delta), ...errors],
      warnings: _mergedWarnings(ledger, parsed, filename, startLine, oldEnd, delta),
      options: replayLedgerOptions(_mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta)),
      info: _mergedInfo(
        ledger,
        parsed,
        filename,
        startLine,
        oldEnd,
        delta,
        info,
        directives: switch (ledger) {
          ParsedLedgerDirectives(:final List<ParsedDirective> directives) => <ParsedDirective>[
            for (final ParsedDirective directive in directives)
              if (!directive.location.overlapsFileRange(filename, startLine, oldEnd))
                _shiftDirective(directive, filename, oldEnd, delta),
          ],
          ParsedLedgerErrors() => const <ParsedDirective>[],
        },
      ),
    ),
    (ParsedLedgerErrors(:final List<ParseError> errors), ParsedLedgerDirectives()) => _errorsOrDirectives(
      errors: _shiftedErrors(_withoutOverlappingErrors(errors, filename, startLine, oldEnd), filename, oldEnd, delta),
      directives: _mergedDirectives(const <ParsedDirective>[], parsed, filename, startLine, oldEnd, delta),
      ledger: ledger,
      parsed: parsed,
      filename: filename,
      startLine: startLine,
      oldEnd: oldEnd,
      delta: delta,
    ),
    (ParsedLedgerDirectives(:final List<ParsedDirective> directives), ParsedLedgerDirectives()) => _splicedDirectives(
      directives: _mergedDirectives(directives, parsed, filename, startLine, oldEnd, delta),
      ledger: ledger,
      parsed: parsed,
      filename: filename,
      startLine: startLine,
      oldEnd: oldEnd,
      delta: delta,
    ),
  };
}

ParsedLedger _splicedDirectives({
  required List<ParsedDirective> directives,
  required ParsedLedger ledger,
  required ParsedLedger parsed,
  required String filename,
  required int startLine,
  required int oldEnd,
  required int delta,
}) => ParsedLedger.directives(
  directives: directives,
  warnings: _mergedWarnings(ledger, parsed, filename, startLine, oldEnd, delta),
  options: replayLedgerOptions(_mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta)),
  info: _mergedInfo(ledger, parsed, filename, startLine, oldEnd, delta, parsed.info, directives: directives),
);

ParsedLedger _errorsOrDirectives({
  required List<ParseError> errors,
  required List<ParsedDirective> directives,
  required ParsedLedger ledger,
  required ParsedLedger parsed,
  required String filename,
  required int startLine,
  required int oldEnd,
  required int delta,
}) {
  final List<OptionSetting> settings = _mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta);
  final LedgerOptions options = replayLedgerOptions(settings);
  final ProcessingInfo info = _mergedInfo(
    ledger,
    parsed,
    filename,
    startLine,
    oldEnd,
    delta,
    parsed.info,
    directives: directives,
  );
  if (errors.isNotEmpty) {
    return ParsedLedger.errors(
      errors: errors,
      warnings: _mergedWarnings(ledger, parsed, filename, startLine, oldEnd, delta),
      options: options,
      info: info,
    );
  }
  return ParsedLedger.directives(
    directives: directives,
    warnings: _mergedWarnings(ledger, parsed, filename, startLine, oldEnd, delta),
    options: options,
    info: info,
  );
}

List<ParseWarning> _mergedWarnings(
  ParsedLedger ledger,
  ParsedLedger parsed,
  String filename,
  int startLine,
  int oldEnd,
  int delta,
) {
  final List<ParseWarning> kept = <ParseWarning>[
    for (final ParseWarning warning in ledger.warnings)
      if (!warning.location.overlapsFileRange(filename, startLine, oldEnd))
        warning.location.filename == filename && warning.location.linenoBegin > oldEnd
            ? warning.copyWith(location: warning.location.shifted(delta))
            : warning,
  ];
  return <ParseWarning>[...kept, ...parsed.warnings];
}

List<ParseError> _keptErrors(ParsedLedger ledger, String filename, int startLine, int oldEnd, int delta) {
  final List<ParseError> errors = switch (ledger) {
    ParsedLedgerErrors(:final List<ParseError> errors) => errors,
    ParsedLedgerDirectives() => const <ParseError>[],
  };
  return _shiftedErrors(_withoutOverlappingErrors(errors, filename, startLine, oldEnd), filename, oldEnd, delta);
}

List<ParseError> _withoutOverlappingErrors(List<ParseError> errors, String filename, int startLine, int oldEnd) =>
    <ParseError>[
      for (final ParseError error in errors)
        if (!error.location.overlapsFileRange(filename, startLine, oldEnd)) error,
    ];

List<ParseError> _shiftedErrors(List<ParseError> errors, String filename, int oldEnd, int delta) => <ParseError>[
  for (final ParseError error in errors)
    error.location.filename == filename && error.location.linenoBegin > oldEnd
        ? error.copyWith(location: error.location.shifted(delta))
        : error,
];

List<ParsedDirective> _mergedDirectives(
  List<ParsedDirective> existing,
  ParsedLedger parsed,
  String filename,
  int startLine,
  int oldEnd,
  int delta,
) {
  final List<ParsedDirective> kept = <ParsedDirective>[
    for (final ParsedDirective directive in existing)
      if (!directive.location.overlapsFileRange(filename, startLine, oldEnd))
        _shiftDirective(directive, filename, oldEnd, delta),
  ];
  final List<ParsedDirective> added = switch (parsed) {
    ParsedLedgerDirectives(:final List<ParsedDirective> directives) => directives,
    ParsedLedgerErrors() => const <ParsedDirective>[],
  };
  return <ParsedDirective>[...kept, ...added]..sort(compareParsedDirectives);
}

ParsedDirective _shiftDirective(ParsedDirective directive, String filename, int oldEnd, int delta) {
  if (delta == 0 || directive.location.filename != filename || directive.location.linenoBegin <= oldEnd) {
    return directive;
  }
  return directive.copyWith(
    location: directive.location.shifted(delta),
    body: switch (directive.body) {
      TransactionBody(:final ParsedTransaction value) => DirectiveBody.transaction(
        value.copyWith(
          postings: <ParsedPosting>[
            for (final ParsedPosting posting in value.postings)
              posting.location.filename == filename && posting.location.linenoBegin > oldEnd
                  ? posting.copyWith(location: posting.location.shifted(delta))
                  : posting,
          ],
        ),
      ),
      _ => directive.body,
    },
  );
}

List<OptionSetting> _mergedSettings(
  ParsedLedger ledger,
  ParsedLedger parsed,
  String filename,
  int startLine,
  int oldEnd,
  int delta,
) {
  final List<OptionSetting> existing = ledger.info.optionSettings;
  final List<OptionSetting> added = parsed.info.optionSettings;
  final List<OptionSetting> kept = <OptionSetting>[
    for (final OptionSetting setting in existing)
      if (!setting.location.overlapsFileRange(filename, startLine, oldEnd))
        setting.location.filename == filename && setting.location.linenoBegin > oldEnd
            ? setting.copyWith(location: setting.location.shifted(delta))
            : setting,
  ];
  return <OptionSetting>[...kept, ...added];
}

ProcessingInfo _mergedInfo(
  ParsedLedger ledger,
  ParsedLedger parsed,
  String filename,
  int startLine,
  int oldEnd,
  int delta,
  ProcessingInfo snippetInfo, {
  required List<ParsedDirective> directives,
}) {
  final List<Plugin> keptPlugins = <Plugin>[
    for (final Plugin plugin in ledger.info.plugin)
      if (!plugin.location.overlapsFileRange(filename, startLine, oldEnd))
        plugin.location.filename == filename && plugin.location.linenoBegin > oldEnd
            ? plugin.copyWith(location: plugin.location.shifted(delta))
            : plugin,
  ];
  final List<String> includes = <String>[...ledger.info.include];
  for (final String path in snippetInfo.include) {
    if (!includes.contains(path)) {
      includes.add(path);
    }
  }
  final ({List<Currency> commodities, DisplayContext displayContext}) observed = observeDirectives(directives);
  return ProcessingInfo(
    filename: ledger.info.filename ?? snippetInfo.filename,
    include: includes,
    commodities: observed.commodities,
    plugin: <Plugin>[...keptPlugins, ...snippetInfo.plugin],
    displayContext: observed.displayContext,
    optionSettings: _mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta),
  );
}

int _snippetLineCount(String source) {
  final String normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.isEmpty) {
    return 0;
  }
  final List<String> lines = normalized.split('\n');
  return lines.last.isEmpty ? lines.length - 1 : lines.length;
}
