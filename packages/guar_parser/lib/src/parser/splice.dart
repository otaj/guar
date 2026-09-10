// Merges a parsed snippet into an existing ledger by source span.

import '../domain/domain.dart';
import 'grammar.dart';
import 'include.dart';
import 'observation.dart';
import 'option_apply.dart';

ParsedLedger spliceLedger(
  ParsedLedger ledger,
  String snippet, {
  required String filename,
  required int startLine,
  required int endLine,
}) {
  final oldEnd = endLine < startLine ? startLine - 1 : endLine;
  final snippetLines = _snippetLineCount(snippet);
  final delta = snippetLines - (oldEnd >= startLine ? oldEnd - startLine + 1 : 0);
  final parsed = BeancountGrammar(
    filename: filename,
    firstLine: startLine,
    includes: IncludeController.io(),
  ).parse(snippet, initialOptions: ledger.options);
  return switch ((ledger, parsed)) {
    (_, ParsedLedgerErrors(:final errors, :final info)) => ParsedLedger.errors(
      errors: [..._keptErrors(ledger, filename, startLine, oldEnd, delta), ...errors],
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
          ParsedLedgerDirectives(:final directives) => [
            for (final directive in directives)
              if (!directive.location.overlapsFileRange(filename, startLine, oldEnd))
                _shiftDirective(directive, filename, oldEnd, delta),
          ],
          ParsedLedgerErrors() => const [],
        },
      ),
    ),
    (ParsedLedgerErrors(:final errors), ParsedLedgerDirectives()) => _errorsOrDirectives(
      errors: _shiftedErrors(_withoutOverlappingErrors(errors, filename, startLine, oldEnd), filename, oldEnd, delta),
      directives: _mergedDirectives(const [], parsed, filename, startLine, oldEnd, delta),
      ledger: ledger,
      parsed: parsed,
      filename: filename,
      startLine: startLine,
      oldEnd: oldEnd,
      delta: delta,
    ),
    (ParsedLedgerDirectives(:final directives), ParsedLedgerDirectives()) => _splicedDirectives(
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
}) {
  return ParsedLedger.directives(
    directives: directives,
    options: replayLedgerOptions(_mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta)),
    info: _mergedInfo(ledger, parsed, filename, startLine, oldEnd, delta, parsed.info, directives: directives),
  );
}

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
  final settings = _mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta);
  final options = replayLedgerOptions(settings);
  final info = _mergedInfo(ledger, parsed, filename, startLine, oldEnd, delta, parsed.info, directives: directives);
  if (errors.isNotEmpty) {
    return ParsedLedger.errors(errors: errors, options: options, info: info);
  }
  return ParsedLedger.directives(directives: directives, options: options, info: info);
}

List<ParseError> _keptErrors(ParsedLedger ledger, String filename, int startLine, int oldEnd, int delta) {
  final errors = switch (ledger) {
    ParsedLedgerErrors(:final errors) => errors,
    ParsedLedgerDirectives() => const <ParseError>[],
  };
  return _shiftedErrors(_withoutOverlappingErrors(errors, filename, startLine, oldEnd), filename, oldEnd, delta);
}

List<ParseError> _withoutOverlappingErrors(List<ParseError> errors, String filename, int startLine, int oldEnd) {
  return [
    for (final error in errors)
      if (!error.location.overlapsFileRange(filename, startLine, oldEnd)) error,
  ];
}

List<ParseError> _shiftedErrors(List<ParseError> errors, String filename, int oldEnd, int delta) {
  return [
    for (final error in errors)
      error.location.filename == filename && error.location.linenoBegin > oldEnd
          ? error.copyWith(location: error.location.shifted(delta))
          : error,
  ];
}

List<ParsedDirective> _mergedDirectives(
  List<ParsedDirective> existing,
  ParsedLedger parsed,
  String filename,
  int startLine,
  int oldEnd,
  int delta,
) {
  final kept = [
    for (final directive in existing)
      if (!directive.location.overlapsFileRange(filename, startLine, oldEnd))
        _shiftDirective(directive, filename, oldEnd, delta),
  ];
  final added = switch (parsed) {
    ParsedLedgerDirectives(:final directives) => directives,
    ParsedLedgerErrors() => const <ParsedDirective>[],
  };
  return [...kept, ...added]..sort(compareParsedDirectives);
}

ParsedDirective _shiftDirective(ParsedDirective directive, String filename, int oldEnd, int delta) {
  if (delta == 0 || directive.location.filename != filename || directive.location.linenoBegin <= oldEnd) {
    return directive;
  }
  return directive.copyWith(
    location: directive.location.shifted(delta),
    body: switch (directive.body) {
      TransactionBody(:final value) => DirectiveBody.transaction(
        value.copyWith(
          postings: [
            for (final posting in value.postings)
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
  final existing = ledger.info.optionSettings;
  final added = parsed.info.optionSettings;
  final kept = [
    for (final setting in existing)
      if (!setting.location.overlapsFileRange(filename, startLine, oldEnd))
        setting.location.filename == filename && setting.location.linenoBegin > oldEnd
            ? setting.copyWith(location: setting.location.shifted(delta))
            : setting,
  ];
  return [...kept, ...added];
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
  final keptPlugins = [
    for (final plugin in ledger.info.plugin)
      if (!plugin.location.overlapsFileRange(filename, startLine, oldEnd))
        plugin.location.filename == filename && plugin.location.linenoBegin > oldEnd
            ? plugin.copyWith(location: plugin.location.shifted(delta))
            : plugin,
  ];
  final includes = [...ledger.info.include];
  for (final path in snippetInfo.include) {
    if (!includes.contains(path)) {
      includes.add(path);
    }
  }
  final observed = observeDirectives(directives);
  return ProcessingInfo(
    filename: ledger.info.filename ?? snippetInfo.filename,
    include: includes,
    commodities: observed.commodities,
    plugin: [...keptPlugins, ...snippetInfo.plugin],
    displayContext: observed.displayContext,
    optionSettings: _mergedSettings(ledger, parsed, filename, startLine, oldEnd, delta),
  );
}

int _snippetLineCount(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.isEmpty) {
    return 0;
  }
  final lines = normalized.split('\n');
  return lines.last.isEmpty ? lines.length - 1 : lines.length;
}
