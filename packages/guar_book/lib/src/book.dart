// Orchestrates option defaults, booking, built-in stages, plugins, and validation.

import 'package:guar_book/src/booking/book_directives.dart';
import 'package:guar_book/src/diff.dart';
import 'package:guar_book/src/options_defaults.dart';
import 'package:guar_book/src/stage_result.dart';
import 'package:guar_book/src/stages/balance.dart';
import 'package:guar_book/src/stages/documents.dart';
import 'package:guar_book/src/stages/pad.dart';
import 'package:guar_book/src/validate/validate.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:guar_plugins/guar_plugins.dart';

class Book {
  Book({Map<String, BookPlugin> plugins = const <String, BookPlugin>{}})
    : plugins = <String, BookPlugin>{...defaultPlugins, ...plugins};

  final Map<String, BookPlugin> plugins;

  Ledger process(p.ParsedLedger ledger, {bool recover = false}) {
    final LedgerOptions options = defaultOptions(ledger.options);
    final ProcessingInfo info = mapInfo(ledger.info);
    final List<ProcessingWarning> warnings = <ProcessingWarning>[
      for (final p.ParseWarning warning in ledger.warnings)
        ProcessingWarning(message: warning.message, location: mapLocation(warning.location)),
    ];

    switch (ledger) {
      case p.ParsedLedgerErrors(:final List<p.ParseError> errors):
        return Ledger.errors(
          errors: <ProcessingError>[
            for (final p.ParseError error in errors)
              ProcessingError(message: error.message, location: mapLocation(error.location)),
          ],
          warnings: warnings,
          options: options,
          info: info,
        );
      case p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives, :final List<p.ParseError> errors):
        return _processDirectives(directives, options, info, recover: recover, parseErrors: errors, warnings: warnings);
    }
  }

  Ledger splice(
    p.ParsedLedger ledger,
    String snippet, {
    required String filename,
    required int startLine,
    required int endLine,
  }) {
    final p.ParsedLedger spliced = const p.BeancountParser().splice(
      ledger,
      snippet,
      filename: filename,
      startLine: startLine,
      endLine: endLine,
    );
    return process(spliced);
  }

  LedgerDiff diff(Ledger left, Ledger right) => diffLedgers(left, right);

  Ledger _processDirectives(
    List<p.ParsedDirective> parsed,
    LedgerOptions options,
    ProcessingInfo info, {
    required bool recover,
    List<p.ParseError> parseErrors = const <p.ParseError>[],
    List<ProcessingWarning> warnings = const <ProcessingWarning>[],
  }) {
    final List<ProcessingError> accumulated = <ProcessingError>[
      for (final p.ParseError error in parseErrors)
        ProcessingError(message: error.message, location: mapLocation(error.location)),
    ];
    final StageResult booked = bookDirectives(parsed: parsed, options: options);
    accumulated.addAll(booked.errors);
    if (booked.hasErrors && !recover) {
      return Ledger.errors(errors: accumulated, warnings: warnings, options: options, info: info);
    }

    List<Directive> directives = booked.directives;

    final bool raw = options.pluginProcessingMode == PluginProcessingMode.raw;
    if (!raw) {
      final StageResult docs = applyDocuments(directives, options, info);
      directives = docs.directives;
      accumulated.addAll(docs.errors);

      final StageResult padded = applyPad(directives, options, info);
      directives = padded.directives;
      accumulated.addAll(padded.errors);
    }

    for (final Plugin plugin in info.plugin) {
      final BookPlugin? callback = plugins[plugin.name];
      if (callback == null) {
        accumulated.add(ProcessingError(message: 'plugin not registered: ${plugin.name}', location: plugin.location));
        continue;
      }
      final BookPluginResult result = callback(directives, options, info, plugin.config);
      directives = result.directives;
      accumulated.addAll(result.errors);
    }

    if (!raw) {
      final StageResult balances = applyBalance(directives, options);
      accumulated
        ..addAll(balances.errors)
        ..addAll(validateDirectives(directives, options));
    }

    if (accumulated.isNotEmpty && !recover) {
      return Ledger.errors(errors: accumulated, warnings: warnings, options: options, info: info);
    }
    return Ledger.directives(
      directives: directives,
      errors: accumulated,
      warnings: warnings,
      options: options,
      info: info,
    );
  }
}
