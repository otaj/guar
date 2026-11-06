// Books the text of the open ledger file.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as parser;

typedef _SourceDirective = ({String filename, int line, String kind});

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

BookedLedger bookLedger(String source, {String filename = ''}) {
  // Included paths are not files the app has opened. Keep a directive when a later check fails.
  final parser.ParsedLedger parsed = const parser.BeancountParser().parse(
    source,
    filename: filename,
    recover: true,
    followIncludes: false,
  );
  final LoadedLedgerOptions loaded = readLedgerOptions(source);
  return BookedLedger._(
    ledger: Book().process(parsed, recover: true),
    guar: loaded.guar,
    optionWarnings: <String>[
      for (final String message in loaded.errors)
        if (message.startsWith('hide_')) message,
    ],
    sourceDirectives: _parsedSources(parsed),
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
