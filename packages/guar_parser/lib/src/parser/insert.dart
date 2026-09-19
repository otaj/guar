// Places an in-memory construct into a ParsedLedger using insert-entry routing.

import 'package:guar_parser/src/domain/domain.dart';
import 'package:guar_parser/src/parser/grammar.dart';
import 'package:guar_parser/src/parser/insert_route.dart';
import 'package:guar_parser/src/parser/observation.dart';
import 'package:guar_parser/src/parser/option_apply.dart';

ParsedLedger insertDirective(ParsedLedger ledger, ParsedDirective directive) => switch (ledger) {
  ParsedLedgerErrors() => ledger,
  ParsedLedgerDirectives() => _insertDated(ledger, directive),
};

ParsedLedger insertOptionSetting(ParsedLedger ledger, String key, String value) => switch (ledger) {
  ParsedLedgerErrors() => ledger,
  ParsedLedgerDirectives() => _insertOption(ledger, key, value),
};

ParsedLedger insertPluginSetting(ParsedLedger ledger, String name, {String? config}) => switch (ledger) {
  ParsedLedgerErrors() => ledger,
  ParsedLedgerDirectives() => _insertPlugin(ledger, name, config),
};

ParsedLedger _insertDated(ParsedLedgerDirectives ledger, ParsedDirective directive) {
  final BeanLocation dest = insertLocation(
    date: directive.date,
    body: directive.body,
    existing: ledger.directives,
    info: ledger.info,
  );
  final ParsedDirective placed = _placeAt(directive, dest.filename, dest.linenoBegin);
  final int span = _span(placed);
  final List<ParsedDirective> shifted = <ParsedDirective>[
    for (final ParsedDirective existing in ledger.directives)
      _shiftFrom(existing, dest.filename, dest.linenoBegin, span),
  ];
  final List<ParsedDirective> directives = <ParsedDirective>[...shifted, placed]..sort(compareParsedDirectives);
  final ({List<Currency> commodities, DisplayContext displayContext}) observed = observeDirectives(directives);
  return ParsedLedger.directives(
    directives: directives,
    errors: ledger.errors,
    warnings: <ParseWarning>[
      for (final ParseWarning warning in ledger.warnings)
        _shiftLocation(warning.location, dest.filename, dest.linenoBegin, span) == warning.location
            ? warning
            : warning.copyWith(location: _shiftLocation(warning.location, dest.filename, dest.linenoBegin, span)),
    ],
    options: ledger.options,
    info: ledger.info.copyWith(
      commodities: observed.commodities,
      displayContext: observed.displayContext,
      optionSettings: <OptionSetting>[
        for (final OptionSetting setting in ledger.info.optionSettings)
          setting.copyWith(location: _shiftLocation(setting.location, dest.filename, dest.linenoBegin, span)),
      ],
      plugin: <Plugin>[
        for (final Plugin plugin in ledger.info.plugin)
          plugin.copyWith(location: _shiftLocation(plugin.location, dest.filename, dest.linenoBegin, span)),
      ],
    ),
  );
}

ParsedLedger _insertOption(ParsedLedgerDirectives ledger, String key, String value) {
  final (LedgerOptions, String?) applied = applyLedgerOption(ledger.options, key, value);
  final BeanLocation location = optionPluginLocation(ledger.info);
  final String root = location.filename;
  if (applied.$2 != null) {
    return ParsedLedger.errors(
      errors: <ParseError>[ParseError(message: applied.$2!, location: location)],
      warnings: ledger.warnings,
      options: ledger.options,
      info: ledger.info,
    );
  }
  const int span = 1;
  final List<ParsedDirective> shifted = <ParsedDirective>[
    for (final ParsedDirective existing in ledger.directives) _shiftFrom(existing, root, 1, span),
  ];
  final String? warning = ledgerOptionWarning(key);
  return ParsedLedger.directives(
    directives: shifted..sort(compareParsedDirectives),
    errors: ledger.errors,
    warnings: <ParseWarning>[
      for (final ParseWarning item in ledger.warnings)
        item.copyWith(location: _shiftLocation(item.location, root, 1, span)),
      if (warning != null) ParseWarning(message: warning, location: location),
    ],
    options: applied.$1,
    info: ledger.info.copyWith(
      optionSettings: <OptionSetting>[
        for (final OptionSetting setting in ledger.info.optionSettings)
          setting.copyWith(location: _shiftLocation(setting.location, root, 1, span)),
        OptionSetting(location: location, key: key, value: value),
      ],
      plugin: <Plugin>[
        for (final Plugin plugin in ledger.info.plugin)
          plugin.copyWith(location: _shiftLocation(plugin.location, root, 1, span)),
      ],
    ),
  );
}

ParsedLedger _insertPlugin(ParsedLedgerDirectives ledger, String name, String? config) {
  final BeanLocation location = optionPluginLocation(ledger.info);
  final String root = location.filename;
  const int span = 1;
  final List<ParsedDirective> shifted = <ParsedDirective>[
    for (final ParsedDirective existing in ledger.directives) _shiftFrom(existing, root, 1, span),
  ];
  return ParsedLedger.directives(
    directives: shifted..sort(compareParsedDirectives),
    errors: ledger.errors,
    warnings: <ParseWarning>[
      for (final ParseWarning item in ledger.warnings)
        item.copyWith(location: _shiftLocation(item.location, root, 1, span)),
    ],
    options: ledger.options,
    info: ledger.info.copyWith(
      optionSettings: <OptionSetting>[
        for (final OptionSetting setting in ledger.info.optionSettings)
          setting.copyWith(location: _shiftLocation(setting.location, root, 1, span)),
      ],
      plugin: <Plugin>[
        for (final Plugin plugin in ledger.info.plugin)
          plugin.copyWith(location: _shiftLocation(plugin.location, root, 1, span)),
        Plugin(name: name, config: config, location: location),
      ],
    ),
  );
}

int _span(ParsedDirective directive) {
  int lines = 1 + directive.meta.entries.length;
  if (directive.body case TransactionBody(:final ParsedTransaction value)) {
    for (final ParsedPosting posting in value.postings) {
      lines += 1 + posting.meta.entries.length;
    }
  }
  return lines < 1 ? 1 : lines;
}

ParsedDirective _placeAt(ParsedDirective directive, String filename, int startLine) {
  final int span = _span(directive);
  final BeanLocation location = BeanLocation(
    filename: filename,
    linenoBegin: startLine,
    linenoEnd: startLine + span - 1,
  );
  if (directive.body case TransactionBody(:final ParsedTransaction value)) {
    int line = startLine + 1 + directive.meta.entries.length;
    final List<ParsedPosting> postings = <ParsedPosting>[];
    for (final ParsedPosting posting in value.postings) {
      postings.add(
        posting.copyWith(
          location: BeanLocation(filename: filename, linenoBegin: line, linenoEnd: line + posting.meta.entries.length),
        ),
      );
      line += 1 + posting.meta.entries.length;
    }
    return directive.copyWith(
      location: location,
      body: DirectiveBody.transaction(value.copyWith(postings: postings)),
    );
  }
  return directive.copyWith(location: location);
}

ParsedDirective _shiftFrom(ParsedDirective directive, String filename, int fromLine, int delta) {
  if (delta == 0 || directive.location.filename != filename || directive.location.linenoBegin < fromLine) {
    return directive;
  }
  return directive.copyWith(
    location: directive.location.shifted(delta),
    body: switch (directive.body) {
      TransactionBody(:final ParsedTransaction value) => DirectiveBody.transaction(
        value.copyWith(
          postings: <ParsedPosting>[
            for (final ParsedPosting posting in value.postings)
              posting.location.filename == filename && posting.location.linenoBegin >= fromLine
                  ? posting.copyWith(location: posting.location.shifted(delta))
                  : posting,
          ],
        ),
      ),
      _ => directive.body,
    },
  );
}

BeanLocation _shiftLocation(BeanLocation location, String filename, int fromLine, int delta) {
  if (delta == 0 || location.filename != filename || location.linenoBegin < fromLine) {
    return location;
  }
  return location.shifted(delta);
}
