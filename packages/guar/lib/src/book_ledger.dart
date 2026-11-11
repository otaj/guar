// Books the text of the open ledger file.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as parser;

typedef _SourceDirective = ({String filename, int line, String kind});

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.source,
    required this.filename,
    required this.booked,
    required this.options,
    required this.plugins,
  });

  final String source;
  final String filename;
  final BookedLedger booked;
  final LoadedLedgerOptions options;
  final List<LedgerPlugin> plugins;
}

class BookedLedger {
  const BookedLedger._({
    required this.ledger,
    required this.guar,
    required this.optionWarnings,
    required this._sourceDirectives,
  });

  final Ledger ledger;
  final GuarOptions guar;
  final List<String> optionWarnings;
  final Set<_SourceDirective> _sourceDirectives;

  // Plugin and pad inserts keep a source location for where they would be written.
  bool isGenerated(Directive directive) => switch (directive.origin) {
    GeneratedOrigin() => true,
    SourceOrigin(:final BeanLocation location) => !_sourceDirectives.contains((
      filename: location.filename,
      line: location.linenoBegin,
      kind: directiveHideToken(directive.body),
    )),
  };
}

LedgerSnapshot prepareLedger(
  String source, {
  String filename = '',
  parser.ParsedLedger? parsed,
  parser.ParsedLedger? parsedIncludes,
}) {
  // Included paths are not files the app has opened. Keep a directive when a later check fails.
  final parser.ParsedLedger root =
      parsed ?? const parser.BeancountParser().parse(source, filename: filename, recover: true, followIncludes: false);
  final LoadedLedgerOptions loaded = readLedgerOptionsFrom(source, root);
  return LedgerSnapshot(
    source: source,
    filename: filename,
    booked: BookedLedger._(
      ledger: Book().process(parsedIncludes ?? root, recover: true),
      guar: loaded.guar,
      optionWarnings: <String>[
        for (final String message in loaded.errors)
          if (message.startsWith('hide_')) message,
      ],
      sourceDirectives: _parsedSources(root),
    ),
    options: loaded,
    plugins: readLedgerPluginsFrom(root),
  );
}

Set<_SourceDirective> _parsedSources(parser.ParsedLedger parsed) {
  final List<parser.ParsedDirective> directives = switch (parsed) {
    parser.ParsedLedgerDirectives(:final List<parser.ParsedDirective> directives) => directives,
    parser.ParsedLedgerErrors() => const <parser.ParsedDirective>[],
  };
  return <_SourceDirective>{
    for (final parser.ParsedDirective directive in directives)
      (
        filename: directive.location.filename,
        line: directive.location.linenoBegin,
        kind: parsedHideToken(directive.body),
      ),
  };
}
