// Orchestrates option defaults, booking, built-in stages, plugins, and validation.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;

import 'booking/book_directives.dart';
import 'diff.dart';
import 'options_defaults.dart';
import 'plugin.dart';
import 'plugins/stock.dart';
import 'stages/balance.dart';
import 'stages/documents.dart';
import 'stages/pad.dart';
import 'validate/validate.dart';

class Book {
  Book({Map<String, BookPlugin> plugins = const {}}) : plugins = {...stockPlugins, ...plugins};

  final Map<String, BookPlugin> plugins;

  Ledger process(p.ParsedLedger ledger) {
    final options = defaultOptions(ledger.options);
    final info = mapInfo(ledger.info);

    switch (ledger) {
      case p.ParsedLedgerErrors(:final errors):
        return Ledger.errors(
          errors: [
            for (final error in errors) ProcessingError(message: error.message, location: mapLocation(error.location)),
          ],
          options: options,
          info: info,
        );
      case p.ParsedLedgerDirectives(:final directives):
        return _processDirectives(directives, options, info);
    }
  }

  Ledger splice(
    p.ParsedLedger ledger,
    String snippet, {
    required String filename,
    required int startLine,
    required int endLine,
  }) {
    final spliced = const p.BeancountParser().splice(
      ledger,
      snippet,
      filename: filename,
      startLine: startLine,
      endLine: endLine,
    );
    return process(spliced);
  }

  LedgerDiff diff(Ledger left, Ledger right) => diffLedgers(left, right);

  Ledger _processDirectives(List<p.ParsedDirective> parsed, LedgerOptions options, ProcessingInfo info) {
    final booked = bookDirectives(parsed: parsed, options: options);
    if (booked.hasErrors) {
      return Ledger.errors(errors: booked.errors, options: options, info: info);
    }

    var directives = booked.directives;
    final accumulated = <ProcessingError>[];

    final raw = options.pluginProcessingMode == PluginProcessingMode.raw;
    if (!raw) {
      final docs = applyDocuments(directives, options, info);
      directives = docs.directives;
      accumulated.addAll(docs.errors);

      final padded = applyPad(directives, options);
      directives = padded.directives;
      accumulated.addAll(padded.errors);

      final balances = applyBalance(directives, options);
      accumulated.addAll(balances.errors);
    }

    for (final plugin in info.plugin) {
      final callback = plugins[plugin.name];
      if (callback == null) {
        accumulated.add(ProcessingError(message: 'plugin not registered: ${plugin.name}', location: plugin.location));
        continue;
      }
      final result = callback(directives, options, info, plugin.config);
      directives = result.directives;
      accumulated.addAll(result.errors);
    }

    if (!raw) {
      accumulated.addAll(validateDirectives(directives, options));
    }

    if (accumulated.isNotEmpty) {
      return Ledger.errors(errors: accumulated, options: options, info: info);
    }
    return Ledger.directives(directives: directives, options: options, info: info);
  }
}
