// Read and write root-file options, including the guar_option custom directive.

import 'package:guar_book/src/options_defaults.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

class GuarOptions {
  const GuarOptions({this.advancedUi = false});

  final bool advancedUi;
}

class LoadedLedgerOptions {
  const LoadedLedgerOptions({required this.options, required this.errors, this.guar = const GuarOptions()});

  final d.LedgerOptions options;
  final List<String> errors;
  final GuarOptions guar;
}

LoadedLedgerOptions readLedgerOptions(String source) {
  final p.ParsedLedger parsed = _parse(source);
  final _AdvancedUiScan guar = _scanAdvancedUi(source, parsed);
  return LoadedLedgerOptions(
    options: defaultOptions(parsed.options),
    errors: <String>[for (final p.ParseError error in parsed.errors) error.message, ...guar.errors],
    guar: GuarOptions(advancedUi: guar.value),
  );
}

String writeLedgerOptions(String source, d.LedgerOptions options, {GuarOptions? guar, DateTime? today}) {
  final String written = _writeOptionLines(source, options);
  if (guar == null) {
    return written;
  }
  return _writeAdvancedUi(written, enabled: guar.advancedUi, today: today ?? DateTime.now());
}

String _writeOptionLines(String source, d.LedgerOptions options) {
  final List<String> rendered = explicitOptionLines(options);
  final p.ParsedLedger parsed = _parse(source);
  final p.ProcessingInfo info = switch (parsed) {
    p.ParsedLedgerDirectives(:final p.ProcessingInfo info) => info,
    p.ParsedLedgerErrors(:final p.ProcessingInfo info) => info,
  };
  final _Text text = _split(source);
  final List<({int start, int end})> spans = <({int start, int end})>[];
  for (final p.OptionSetting setting in info.optionSettings) {
    final int start = setting.location.linenoBegin - 1;
    if (start < 0 || start >= text.lines.length) {
      continue;
    }
    spans.add((start: start, end: _spanEnd(text.lines, start)));
  }
  spans.sort((({int start, int end}) a, ({int start, int end}) b) => a.start.compareTo(b.start));
  if (rendered.isEmpty && spans.isEmpty) {
    return source;
  }
  final List<String> lines = List<String>.of(text.lines);
  final int insertAt = spans.isEmpty ? 0 : spans.first.start;
  for (final ({int start, int end}) span in spans.reversed) {
    if (span.start >= lines.length) {
      continue;
    }
    final int end = span.end >= lines.length ? lines.length - 1 : span.end;
    lines.removeRange(span.start, end + 1);
  }
  lines.insertAll(insertAt > lines.length ? lines.length : insertAt, rendered);
  final bool trailing = source.isEmpty ? rendered.isNotEmpty : text.trailing;
  return _join(lines, text.separator, trailing);
}

List<String> explicitOptionLines(d.LedgerOptions options) {
  final d.LedgerOptions stock = d.LedgerOptions();
  final d.LedgerOptions derived = d.LedgerOptions(accountPrefixes: options.accountPrefixes);
  final List<String> lines = <String>[];

  void add(String key, String value) {
    lines.add('option ${_quote(key)} ${_quote(value)}');
  }

  if (options.title != stock.title) {
    add('title', options.title);
  }
  for (final String document in options.documents) {
    add('documents', document);
  }
  for (final d.Currency currency in options.operatingCurrency) {
    add('operating_currency', currency.name);
  }
  if (options.conversionCurrency.name != stock.conversionCurrency.name) {
    add('conversion_currency', options.conversionCurrency.name);
  }
  if (options.renderCommas) {
    add('render_commas', 'TRUE');
  }
  if (options.longStringMaxlines != stock.longStringMaxlines) {
    add('long_string_maxlines', '${options.longStringMaxlines}');
  }
  if (options.pluginProcessingMode == d.PluginProcessingMode.raw) {
    add('plugin_processing_mode', 'RAW');
  }
  if (options.insertPythonpath) {
    add('insert_pythonpath', 'TRUE');
  }
  if (options.allowPipeSeparator) {
    add('allow_pipe_separator', 'TRUE');
  }
  if (options.allowDeprecatedNoneForTagsAndLinks) {
    add('allow_deprecated_none_for_tags_and_links', 'TRUE');
  }
  _prefix(add, 'name_assets', options.accountPrefixes.assets, stock.accountPrefixes.assets);
  _prefix(add, 'name_liabilities', options.accountPrefixes.liabilities, stock.accountPrefixes.liabilities);
  _prefix(add, 'name_equity', options.accountPrefixes.equity, stock.accountPrefixes.equity);
  _prefix(add, 'name_income', options.accountPrefixes.income, stock.accountPrefixes.income);
  _prefix(add, 'name_expenses', options.accountPrefixes.expenses, stock.accountPrefixes.expenses);
  _account(add, 'account_previous_balances', options.accountPreviousBalances, derived.accountPreviousBalances);
  _account(add, 'account_previous_earnings', options.accountPreviousEarnings, derived.accountPreviousEarnings);
  _account(add, 'account_previous_conversions', options.accountPreviousConversions, derived.accountPreviousConversions);
  _account(add, 'account_current_earnings', options.accountCurrentEarnings, derived.accountCurrentEarnings);
  _account(add, 'account_current_conversions', options.accountCurrentConversions, derived.accountCurrentConversions);
  final d.Account? rounding = options.accountRounding;
  if (rounding != null) {
    add('account_rounding', rounding.name);
  }
  _account(add, 'account_unrealized_gains', options.accountUnrealizedGains, derived.accountUnrealizedGains);
  if (options.bookingMethod != stock.bookingMethod) {
    add('booking_method', _booking(options.bookingMethod));
  }
  if (options.usePreciseInterpolation) {
    add('use_precise_interpolation', 'TRUE');
  }
  if (options.inferToleranceFromCost) {
    add('infer_tolerance_from_cost', 'TRUE');
  }
  _number(add, 'tolerance_multiplier', options.toleranceMultiplier, stock.toleranceMultiplier);
  _number(add, 'inferred_tolerance_multiplier', options.inferredToleranceMultiplier, stock.inferredToleranceMultiplier);
  for (final d.InferredTolerance tolerance in options.inferredToleranceDefault) {
    add('inferred_tolerance_default', '${_currencyKey(tolerance.key)}:${tolerance.value}');
  }
  for (final d.DisplayPrecision precision in options.displayPrecision) {
    add('display_precision', '${_precisionKey(precision.key)}:${precision.value}');
  }
  return lines;
}

void _prefix(void Function(String key, String value) add, String key, String value, String fallback) {
  if (value != fallback) {
    add(key, value);
  }
}

void _account(void Function(String key, String value) add, String key, d.Account value, d.Account fallback) {
  if (value.name != fallback.name) {
    add(key, value.name);
  }
}

void _number(void Function(String key, String value) add, String key, d.OptionNumber value, d.OptionNumber fallback) {
  if (value.value != fallback.value) {
    add(key, value.verbatim);
  }
}

String _booking(d.BookingMethod method) => switch (method) {
  d.BookingMethod.strict => 'STRICT',
  d.BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
  d.BookingMethod.none => 'NONE',
  d.BookingMethod.average => 'AVERAGE',
  d.BookingMethod.fifo => 'FIFO',
  d.BookingMethod.lifo => 'LIFO',
  d.BookingMethod.hifo => 'HIFO',
};

String _currencyKey(d.CurrencyKey key) => switch (key) {
  d.CurrencyKeyAll() => '*',
  d.CurrencyKeyCurrency(:final d.Currency value) => value.name,
};

String _precisionKey(d.DisplayPrecisionKey key) => switch (key) {
  d.DisplayPrecisionAll() => '*',
  d.DisplayPrecisionCurrency(:final d.Currency value) => value.name,
  d.DisplayPrecisionPair(:final d.Currency first, :final d.Currency second) => '${first.name}/${second.name}',
};

String _quote(String value) {
  if (value.contains('"')) {
    throw ArgumentError.value(value, 'option', 'Quotes cannot be stored in an option value');
  }
  return '"$value"';
}

p.ParsedLedger _parse(String source) => const p.BeancountParser().parse(source, followIncludes: false, recover: true);

// A quoted option value may continue on the following lines, matching the parser.
int _spanEnd(List<String> lines, int start) {
  final StringBuffer code = StringBuffer(_stripTrailingComment(lines[start]).trimRight());
  int end = start;
  while (_hasUnclosedQuote(code.toString()) && end + 1 < lines.length) {
    end += 1;
    code
      ..write('\n')
      ..write(lines[end]);
  }
  return end;
}

String _stripTrailingComment(String line) {
  bool quoted = false;
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    if (ch == '"') {
      quoted = !quoted;
    } else if (ch == ';' && !quoted) {
      return line.substring(0, i);
    }
  }
  return line;
}

bool _hasUnclosedQuote(String input) {
  bool open = false;
  for (int i = 0; i < input.length; i += 1) {
    final String ch = input[i];
    if (ch == r'\' && open && i + 1 < input.length) {
      i += 1;
      continue;
    }
    if (ch == '"') {
      open = !open;
    }
  }
  return open;
}

class _Text {
  const _Text({required this.lines, required this.separator, required this.trailing});

  final List<String> lines;
  final String separator;
  final bool trailing;
}

_Text _split(String source) {
  final String separator = source.contains('\r\n')
      ? '\r\n'
      : source.contains('\r')
      ? '\r'
      : '\n';
  if (source.isEmpty) {
    return _Text(lines: <String>[], separator: separator, trailing: false);
  }
  final List<String> lines = <String>[];
  final StringBuffer current = StringBuffer();
  for (int i = 0; i < source.length; i++) {
    final int unit = source.codeUnitAt(i);
    final bool cr = unit == 13;
    final bool lf = unit == 10;
    if (!cr && !lf) {
      current.writeCharCode(unit);
      continue;
    }
    lines.add(current.toString());
    current.clear();
    if (cr && i + 1 < source.length && source.codeUnitAt(i + 1) == 10) {
      i += 1;
    }
  }
  final bool trailing = source.endsWith('\n') || source.endsWith('\r');
  if (!trailing) {
    lines.add(current.toString());
  }
  return _Text(lines: lines, separator: separator, trailing: trailing);
}

String _join(List<String> lines, String separator, bool trailing) {
  if (lines.isEmpty) {
    return '';
  }
  final String body = lines.join(separator);
  return trailing ? '$body$separator' : body;
}

const String _advancedUiValueError = 'advanced_ui expects TRUE or FALSE';

class _AdvancedUiHit {
  const _AdvancedUiHit({required this.start, required this.end, required this.date});

  final int start;
  final int end;
  final String date;
}

class _AdvancedUiScan {
  const _AdvancedUiScan({required this.value, required this.errors, required this.hits, required this.insertAt});

  final bool value;
  final List<String> errors;
  final List<_AdvancedUiHit> hits;
  final int insertAt;
}

String _writeAdvancedUi(String source, {required bool enabled, required DateTime today}) {
  final _AdvancedUiScan scan = _scanAdvancedUi(source, _parse(source));
  if (scan.value == enabled) {
    return source;
  }
  final _Text text = _split(source);
  final List<String> lines = List<String>.of(text.lines);
  if (!enabled) {
    _removeHits(lines, scan.hits);
  } else if (scan.hits.isEmpty) {
    final int at = scan.insertAt > lines.length ? lines.length : scan.insertAt;
    lines.insert(at, _advancedUiLine(_isoDate(today)));
  } else {
    final _AdvancedUiHit keep = scan.hits.last;
    final List<_AdvancedUiHit> hits = <_AdvancedUiHit>[...scan.hits]
      ..sort((_AdvancedUiHit a, _AdvancedUiHit b) => a.start.compareTo(b.start));
    for (final _AdvancedUiHit hit in hits.reversed) {
      if (hit.start == keep.start) {
        _replaceSpan(lines, hit.start, hit.end, _advancedUiLine(hit.date));
      } else {
        _removeSpan(lines, hit.start, hit.end);
      }
    }
  }
  final bool trailing = source.isEmpty ? lines.isNotEmpty : text.trailing;
  return _join(lines, text.separator, trailing);
}

void _removeHits(List<String> lines, List<_AdvancedUiHit> hits) {
  final List<_AdvancedUiHit> ordered = <_AdvancedUiHit>[...hits]
    ..sort((_AdvancedUiHit a, _AdvancedUiHit b) => a.start.compareTo(b.start));
  for (final _AdvancedUiHit hit in ordered.reversed) {
    _removeSpan(lines, hit.start, hit.end);
  }
}

_AdvancedUiScan _scanAdvancedUi(String source, p.ParsedLedger parsed) {
  final List<p.ParsedDirective> directives = switch (parsed) {
    p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives) => directives,
    p.ParsedLedgerErrors() => const <p.ParsedDirective>[],
  };
  final _Text text = _split(source);
  bool value = false;
  final List<String> errors = <String>[];
  final List<_AdvancedUiHit> hits = <_AdvancedUiHit>[];
  for (final p.ParsedDirective directive in directives) {
    final p.DirectiveBody body = directive.body;
    if (body is! p.CustomBody || body.type != 'guar_option' || body.values.isEmpty) {
      continue;
    }
    final p.CustomValue key = body.values.first;
    if (key is! p.CustomText || key.value != 'advanced_ui') {
      continue;
    }
    final int start = directive.location.linenoBegin - 1;
    // Quoted values can run past the first line; metadata follows on indented lines.
    final int quotedEnd = start >= 0 && start < text.lines.length ? _spanEnd(text.lines, start) : start;
    final int metaEnd = directive.location.linenoEnd - 1;
    hits.add(
      _AdvancedUiHit(start: start, end: metaEnd > quotedEnd ? metaEnd : quotedEnd, date: directive.date.toString()),
    );
    if (body.values.length < 2) {
      errors.add(_advancedUiValueError);
      continue;
    }
    final bool? parsedValue = _guarBool(body.values[1]);
    if (parsedValue == null) {
      errors.add(_advancedUiValueError);
      continue;
    }
    value = parsedValue;
  }
  int insertAt = 0;
  for (final p.OptionSetting setting in parsed.info.optionSettings) {
    final int start = setting.location.linenoBegin - 1;
    if (start < 0 || start >= text.lines.length) {
      continue;
    }
    final int end = _spanEnd(text.lines, start);
    if (end + 1 > insertAt) {
      insertAt = end + 1;
    }
  }
  return _AdvancedUiScan(value: value, errors: errors, hits: hits, insertAt: insertAt);
}

bool? _guarBool(p.CustomValue value) => switch (value) {
  p.CustomBoolean(:final bool value) => value,
  p.CustomText(:final String value) => _guarTextBool(value),
  p.CustomAccount() || p.CustomDate() || p.CustomNumber() || p.CustomAmount() || p.CustomCurrency() => null,
};

bool? _guarTextBool(String value) => switch (value.toLowerCase()) {
  'true' || '1' => true,
  'false' || '0' => false,
  _ => null,
};

String _advancedUiLine(String date) => '$date custom "guar_option" "advanced_ui" "TRUE"';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void _removeSpan(List<String> lines, int start, int end) {
  if (start < 0 || start >= lines.length) {
    return;
  }
  final int last = end >= lines.length ? lines.length - 1 : end;
  if (last < start) {
    return;
  }
  lines.removeRange(start, last + 1);
}

void _replaceSpan(List<String> lines, int start, int end, String line) {
  if (start < 0 || start >= lines.length) {
    return;
  }
  final int last = end >= lines.length ? lines.length - 1 : end;
  if (last < start) {
    return;
  }
  lines.replaceRange(start, last + 1, <String>[line]);
}
