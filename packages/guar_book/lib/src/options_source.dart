// Read and write root-file options, including the guar_option custom directive.

import 'package:guar_book/src/options_defaults.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

enum GuarHide {
  generated('generated', 'Generated'),
  transaction('transaction', 'Transaction'),
  price('price', 'Price'),
  balance('balance', 'Balance'),
  open('open', 'Open'),
  close('close', 'Close'),
  commodity('commodity', 'Commodity'),
  pad('pad', 'Pad'),
  document('document', 'Document'),
  note('note', 'Note'),
  event('event', 'Event'),
  query('query', 'Query'),
  custom('custom', 'Custom'),
  budget('budget', 'Budget'),
  budgetOff('budget_off', 'Budget off');

  const GuarHide(this.token, this.label);

  final String token;
  final String label;

  String get optionKey => 'hide_$token';
}

String directiveHideToken(d.DirectiveBody body) => switch (body) {
  d.TransactionBody() => GuarHide.transaction.token,
  d.PriceBody() => GuarHide.price.token,
  d.BalanceBody() => GuarHide.balance.token,
  d.OpenBody() => GuarHide.open.token,
  d.CloseBody() => GuarHide.close.token,
  d.CommodityBody() => GuarHide.commodity.token,
  d.PadBody() => GuarHide.pad.token,
  d.DocumentBody() => GuarHide.document.token,
  d.NoteBody() => GuarHide.note.token,
  d.EventBody() => GuarHide.event.token,
  d.QueryBody() => GuarHide.query.token,
  d.CustomBody() => GuarHide.custom.token,
  d.BudgetBody() => GuarHide.budget.token,
  d.BudgetOffBody() => GuarHide.budgetOff.token,
};

String parsedHideToken(p.DirectiveBody body) => switch (body) {
  p.TransactionBody() => GuarHide.transaction.token,
  p.PriceBody() => GuarHide.price.token,
  p.BalanceBody() => GuarHide.balance.token,
  p.OpenBody() => GuarHide.open.token,
  p.CloseBody() => GuarHide.close.token,
  p.CommodityBody() => GuarHide.commodity.token,
  p.PadBody() => GuarHide.pad.token,
  p.DocumentBody() => GuarHide.document.token,
  p.NoteBody() => GuarHide.note.token,
  p.EventBody() => GuarHide.event.token,
  p.QueryBody() => GuarHide.query.token,
  p.CustomBody() => GuarHide.custom.token,
};

class GuarOptions {
  const GuarOptions({this.advancedUi = false, this.writeDefaultOptions = false, this.hidden = const <String>{}});

  final bool advancedUi;
  final bool writeDefaultOptions;

  final Set<String> hidden;
}

class LoadedLedgerOptions {
  const LoadedLedgerOptions({required this.options, required this.errors, this.guar = const GuarOptions()});

  final d.LedgerOptions options;
  final List<String> errors;
  final GuarOptions guar;
}

LoadedLedgerOptions readLedgerOptions(String source) => readLedgerOptionsFrom(source, _parse(source));

LoadedLedgerOptions readLedgerOptionsFrom(String source, p.ParsedLedger parsed) {
  final _GuarBoolScan advancedUi = _scanGuarBool(source, parsed, 'advanced_ui');
  final _GuarBoolScan writeDefaults = _scanGuarBool(source, parsed, 'write_default_options');
  final ({Set<String> values, List<String> errors}) hidden = _readHide(source, parsed);
  return LoadedLedgerOptions(
    options: defaultOptions(parsed.options),
    errors: <String>[
      for (final p.ParseError error in parsed.errors) error.message,
      ...advancedUi.errors,
      ...writeDefaults.errors,
      ...hidden.errors,
    ],
    guar: GuarOptions(
      advancedUi: advancedUi.value,
      writeDefaultOptions: writeDefaults.value,
      hidden: hidden.values,
    ),
  );
}

String writeLedgerOptions(
  String source,
  d.LedgerOptions options, {
  GuarOptions? guar,
  DateTime? today,
  p.ParsedLedger? parsed,
}) {
  final p.ParsedLedger ledger = parsed ?? _parse(source);
  final List<String> rendered = explicitOptionLines(options, writeDefaults: guar?.writeDefaultOptions ?? false);
  final _Text text = _split(source);
  final _Rewrite rewrite = _Rewrite(List<String>.of(text.lines), _optionInsertAt(ledger, text));
  if (guar != null) rewrite.collectGuar(ledger, text);
  final bool rewroteOptions = rewrite.applyOptions(rendered, _optionSpans(ledger, text));
  if (guar != null) {
    final DateTime date = today ?? DateTime.now();
    for (final GuarHide hide in GuarHide.values) {
      rewrite.applyHide(hide, enabled: guar.hidden.contains(hide.token), today: date);
    }
    // New lines insert at the front of the guar block, so later calls stay first.
    rewrite
      ..applyBool(key: 'write_default_options', enabled: guar.writeDefaultOptions, today: date)
      ..applyBool(key: 'advanced_ui', enabled: guar.advancedUi, today: date);
  }
  if (!rewroteOptions && !rewrite.changed) {
    return source;
  }
  final bool trailing = source.isEmpty ? rewrite.lines.isNotEmpty : text.trailing;
  return _join(rewrite.lines, text.separator, trailing);
}

int _optionInsertAt(p.ParsedLedger parsed, _Text text) {
  int at = 0;
  for (final ({int end, int start}) span in _optionSpans(parsed, text)) {
    if (span.end + 1 > at) at = span.end + 1;
  }
  return at;
}

List<({int end, int start})> _optionSpans(p.ParsedLedger parsed, _Text text) {
  final List<({int end, int start})> spans = <({int end, int start})>[];
  for (final p.OptionSetting setting in parsed.info.optionSettings) {
    final int start = setting.location.linenoBegin - 1;
    if (start < 0 || start >= text.lines.length) continue;
    spans.add((start: start, end: _spanEnd(text.lines, start)));
  }
  spans.sort((({int end, int start}) a, ({int end, int start}) b) => a.start.compareTo(b.start));
  return spans;
}

List<String> explicitOptionLines(d.LedgerOptions options, {bool writeDefaults = false}) {
  final d.LedgerOptions stock = d.LedgerOptions();
  final d.LedgerOptions derived = d.LedgerOptions(accountPrefixes: options.accountPrefixes);
  final List<String> lines = <String>[];

  void add(String key, String value) {
    lines.add('option ${_quote(key)} ${_quote(value)}');
  }

  void flag(String key, {required bool value}) {
    if (writeDefaults || value) {
      add(key, value ? 'TRUE' : 'FALSE');
    }
  }

  if (writeDefaults || options.title != stock.title) {
    add('title', options.title);
  }
  for (final String document in options.documents) {
    add('documents', document);
  }
  for (final d.Currency currency in options.operatingCurrency) {
    add('operating_currency', currency.name);
  }
  if (writeDefaults || options.conversionCurrency.name != stock.conversionCurrency.name) {
    add('conversion_currency', options.conversionCurrency.name);
  }
  flag('render_commas', value: options.renderCommas);
  if (writeDefaults || options.longStringMaxlines != stock.longStringMaxlines) {
    add('long_string_maxlines', '${options.longStringMaxlines}');
  }
  if (writeDefaults || options.pluginProcessingMode == d.PluginProcessingMode.raw) {
    add('plugin_processing_mode', options.pluginProcessingMode == d.PluginProcessingMode.raw ? 'RAW' : 'DEFAULT');
  }
  // These keys warn whenever they appear, so a default stays out of the file.
  if (options.insertPythonpath) {
    add('insert_pythonpath', 'TRUE');
  }
  if (options.allowPipeSeparator) {
    add('allow_pipe_separator', 'TRUE');
  }
  if (options.allowDeprecatedNoneForTagsAndLinks) {
    add('allow_deprecated_none_for_tags_and_links', 'TRUE');
  }
  _prefix(
    add,
    'name_assets',
    options.accountPrefixes.assets,
    stock.accountPrefixes.assets,
    writeDefaults: writeDefaults,
  );
  _prefix(
    add,
    'name_liabilities',
    options.accountPrefixes.liabilities,
    stock.accountPrefixes.liabilities,
    writeDefaults: writeDefaults,
  );
  _prefix(
    add,
    'name_equity',
    options.accountPrefixes.equity,
    stock.accountPrefixes.equity,
    writeDefaults: writeDefaults,
  );
  _prefix(
    add,
    'name_income',
    options.accountPrefixes.income,
    stock.accountPrefixes.income,
    writeDefaults: writeDefaults,
  );
  _prefix(
    add,
    'name_expenses',
    options.accountPrefixes.expenses,
    stock.accountPrefixes.expenses,
    writeDefaults: writeDefaults,
  );
  _account(
    add,
    'account_previous_balances',
    options.accountPreviousBalances,
    derived.accountPreviousBalances,
    writeDefaults: writeDefaults,
  );
  _account(
    add,
    'account_previous_earnings',
    options.accountPreviousEarnings,
    derived.accountPreviousEarnings,
    writeDefaults: writeDefaults,
  );
  _account(
    add,
    'account_previous_conversions',
    options.accountPreviousConversions,
    derived.accountPreviousConversions,
    writeDefaults: writeDefaults,
  );
  _account(
    add,
    'account_current_earnings',
    options.accountCurrentEarnings,
    derived.accountCurrentEarnings,
    writeDefaults: writeDefaults,
  );
  _account(
    add,
    'account_current_conversions',
    options.accountCurrentConversions,
    derived.accountCurrentConversions,
    writeDefaults: writeDefaults,
  );
  final d.Account? rounding = options.accountRounding;
  if (rounding != null) {
    add('account_rounding', rounding.name);
  }
  _account(
    add,
    'account_unrealized_gains',
    options.accountUnrealizedGains,
    derived.accountUnrealizedGains,
    writeDefaults: writeDefaults,
  );
  if (writeDefaults || options.bookingMethod != stock.bookingMethod) {
    add('booking_method', _booking(options.bookingMethod));
  }
  flag('use_precise_interpolation', value: options.usePreciseInterpolation);
  flag('infer_tolerance_from_cost', value: options.inferToleranceFromCost);
  _number(
    add,
    'tolerance_multiplier',
    options.toleranceMultiplier,
    stock.toleranceMultiplier,
    writeDefaults: writeDefaults,
  );
  // Renamed option; writing the default would warn on every open.
  _number(
    add,
    'inferred_tolerance_multiplier',
    options.inferredToleranceMultiplier,
    stock.inferredToleranceMultiplier,
    writeDefaults: false,
  );
  for (final d.InferredTolerance tolerance in options.inferredToleranceDefault) {
    add('inferred_tolerance_default', '${_currencyKey(tolerance.key)}:${tolerance.value}');
  }
  for (final d.DisplayPrecision precision in options.displayPrecision) {
    add('display_precision', '${_precisionKey(precision.key)}:${precision.value}');
  }
  return lines;
}

void _prefix(
  void Function(String key, String value) add,
  String key,
  String value,
  String fallback, {
  required bool writeDefaults,
}) {
  if (writeDefaults || value != fallback) {
    add(key, value);
  }
}

void _account(
  void Function(String key, String value) add,
  String key,
  d.Account value,
  d.Account fallback, {
  required bool writeDefaults,
}) {
  if (writeDefaults || value.name != fallback.name) {
    add(key, value.name);
  }
}

void _number(
  void Function(String key, String value) add,
  String key,
  d.OptionNumber value,
  d.OptionNumber fallback, {
  required bool writeDefaults,
}) {
  if (writeDefaults || value.value != fallback.value) {
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

class _MutableSpan {
  _MutableSpan(this.start, this.end, this.date);

  int start;
  int end;
  final String date;
  bool live = true;
}

class _BoolAcc {
  bool value = false;
  final List<_MutableSpan> hits = <_MutableSpan>[];
}

class _HideAcc {
  _HideAcc(this.hide, this.span, {required this.exact});

  final GuarHide? hide;
  final _MutableSpan span;
  final bool exact;
}

class _Rewrite {
  _Rewrite(this.lines, this.optionEnd);

  final List<String> lines;
  int optionEnd;
  final List<_MutableSpan> spans = <_MutableSpan>[];
  final Map<String, _BoolAcc> bools = <String, _BoolAcc>{
    'advanced_ui': _BoolAcc(),
    'write_default_options': _BoolAcc(),
  };
  final List<_HideAcc> hides = <_HideAcc>[];
  bool changed = false;

  void collectGuar(p.ParsedLedger parsed, _Text text) {
    final List<p.ParsedDirective> directives = switch (parsed) {
      p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives) => directives,
      p.ParsedLedgerErrors() => const <p.ParsedDirective>[],
    };
    for (final p.ParsedDirective directive in directives) {
      final p.DirectiveBody body = directive.body;
      if (body is! p.CustomBody || body.type != 'guar_option') continue;
      final int start = directive.location.linenoBegin - 1;
      final int quotedEnd = start >= 0 && start < text.lines.length ? _spanEnd(text.lines, start) : start;
      final int metaEnd = directive.location.linenoEnd - 1;
      final _MutableSpan span = _MutableSpan(
        start,
        metaEnd > quotedEnd ? metaEnd : quotedEnd,
        directive.date.toString(),
      );
      spans.add(span);
      if (body.values.isEmpty || body.values.first is! p.CustomText) continue;
      final String key = (body.values.first as p.CustomText).value;
      final _BoolAcc? acc = bools[key];
      if (acc != null) {
        acc.hits.add(span);
        if (body.values.length >= 2) {
          final bool? parsedValue = _guarBool(body.values[1]);
          if (parsedValue != null) acc.value = parsedValue;
        }
      }
      final GuarHide? hide = _hideForKey(key);
      if (hide == null && key != 'hide_directives' && !key.startsWith('hide_')) continue;
      hides.add(_HideAcc(hide, span, exact: hide != null && _exactHideTrue(body)));
    }
  }

  bool applyOptions(List<String> rendered, List<({int end, int start})> optionSpans) {
    if (rendered.isEmpty && optionSpans.isEmpty) return false;
    final int insertAt = optionSpans.isEmpty ? 0 : optionSpans.first.start;
    for (final ({int end, int start}) span in optionSpans.reversed) {
      if (span.start < 0 || span.start >= lines.length) continue;
      final int end = span.end >= lines.length ? lines.length - 1 : span.end;
      if (end < span.start) continue;
      for (final _MutableSpan guar in spans) {
        if (guar.live && guar.start >= span.start && guar.start <= end) guar.live = false;
      }
      lines.removeRange(span.start, end + 1);
      _shift(span.start, end - span.start + 1, 0, shiftOptionEnd: false);
    }
    final int at = insertAt > lines.length ? lines.length : insertAt;
    lines.insertAll(at, rendered);
    _shift(at, 0, rendered.length, shiftOptionEnd: false);
    optionEnd = at + rendered.length;
    return true;
  }

  void applyHide(GuarHide hide, {required bool enabled, required DateTime today}) {
    final List<_HideAcc> mine = <_HideAcc>[
      for (final _HideAcc look in hides)
        if (look.hide == hide && look.span.live) look,
    ];
    // An inexact line is left alone until this toggle is turned on.
    if ((mine.length == 1 && mine.single.exact) == enabled) return;
    if (!enabled) {
      final List<_HideAcc> ordered = <_HideAcc>[...mine]
        ..sort((_HideAcc a, _HideAcc b) => b.span.start.compareTo(a.span.start));
      for (final _HideAcc look in ordered) {
        _remove(look.span);
      }
      return;
    }
    if (mine.isEmpty) {
      _insert(_hideInsertAt(), _guarBoolLine(_isoDate(today), hide.optionKey));
      return;
    }
    final _HideAcc keep = mine.last;
    final List<_HideAcc> others = <_HideAcc>[
      for (final _HideAcc look in mine)
        if (!identical(look, keep)) look,
    ]..sort((_HideAcc a, _HideAcc b) => b.span.start.compareTo(a.span.start));
    for (final _HideAcc look in others) {
      _remove(look.span);
    }
    _replace(keep.span, _guarBoolLine(keep.span.date, hide.optionKey));
  }

  void applyBool({required String key, required bool enabled, required DateTime today}) {
    final _BoolAcc acc = bools[key]!;
    if (acc.value == enabled) return;
    final List<_MutableSpan> hits = <_MutableSpan>[
      for (final _MutableSpan hit in acc.hits)
        if (hit.live) hit,
    ];
    if (!enabled) {
      hits
        ..sort((_MutableSpan a, _MutableSpan b) => b.start.compareTo(a.start))
        ..forEach(_remove);
      return;
    }
    if (hits.isEmpty) {
      _insert(optionEnd, _guarBoolLine(_isoDate(today), key));
      return;
    }
    final _MutableSpan keep = hits.last;
    <_MutableSpan>[
        for (final _MutableSpan hit in hits)
          if (!identical(hit, keep)) hit,
      ]
      ..sort((_MutableSpan a, _MutableSpan b) => b.start.compareTo(a.start))
      ..forEach(_remove);
    _replace(keep, _guarBoolLine(keep.date, key));
  }

  int _hideInsertAt() {
    int at = optionEnd;
    for (final _MutableSpan span in spans) {
      if (span.live && span.end + 1 > at) at = span.end + 1;
    }
    return at > lines.length ? lines.length : at;
  }

  void _insert(int at, String line) {
    final int index = at > lines.length ? lines.length : at;
    lines.insert(index, line);
    _shift(index, 0, 1);
    spans.add(_MutableSpan(index, index, line));
    changed = true;
  }

  void _remove(_MutableSpan span) {
    if (!span.live || span.start < 0 || span.start >= lines.length) {
      span.live = false;
      return;
    }
    final int end = span.end >= lines.length ? lines.length - 1 : span.end;
    if (end < span.start) {
      span.live = false;
      return;
    }
    lines.removeRange(span.start, end + 1);
    span.live = false;
    _shift(span.start, end - span.start + 1, 0);
    changed = true;
  }

  void _replace(_MutableSpan span, String line) {
    if (!span.live || span.start < 0 || span.start >= lines.length) return;
    final int end = span.end >= lines.length ? lines.length - 1 : span.end;
    if (end < span.start) return;
    final int start = span.start;
    lines.replaceRange(start, end + 1, <String>[line]);
    span
      ..start = start
      ..end = start;
    _shift(start, end - start + 1, 1);
    changed = true;
  }

  void _shift(int at, int removed, int inserted, {bool shiftOptionEnd = true}) {
    final int delta = inserted - removed;
    for (final _MutableSpan span in spans) {
      if (!span.live || span.end < at) continue;
      if (span.start >= at + removed) {
        span
          ..start += delta
          ..end += delta;
      }
    }
    if (shiftOptionEnd && optionEnd > at) {
      if (optionEnd >= at + removed) {
        optionEnd += delta;
      } else {
        optionEnd = at + inserted;
      }
    }
  }
}

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

class _GuarHit {
  const _GuarHit({required this.start, required this.end, required this.date});

  final int start;
  final int end;
  final String date;
}

class _GuarBoolScan {
  const _GuarBoolScan({required this.value, required this.errors, required this.hits});

  final bool value;
  final List<String> errors;
  final List<_GuarHit> hits;
}

_GuarBoolScan _scanGuarBool(String source, p.ParsedLedger parsed, String key) {
  final List<p.ParsedDirective> directives = switch (parsed) {
    p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives) => directives,
    p.ParsedLedgerErrors() => const <p.ParsedDirective>[],
  };
  final _Text text = _split(source);
  bool value = false;
  final List<String> errors = <String>[];
  final List<_GuarHit> hits = <_GuarHit>[];
  final String valueError = '$key expects TRUE or FALSE';
  for (final p.ParsedDirective directive in directives) {
    final p.DirectiveBody body = directive.body;
    if (body is! p.CustomBody || body.type != 'guar_option' || body.values.isEmpty) {
      continue;
    }
    final p.CustomValue name = body.values.first;
    if (name is! p.CustomText || name.value != key) {
      continue;
    }
    final int start = directive.location.linenoBegin - 1;
    // Quoted values can run past the first line; metadata follows on indented lines.
    final int quotedEnd = start >= 0 && start < text.lines.length ? _spanEnd(text.lines, start) : start;
    final int metaEnd = directive.location.linenoEnd - 1;
    hits.add(_GuarHit(start: start, end: metaEnd > quotedEnd ? metaEnd : quotedEnd, date: directive.date.toString()));
    if (body.values.length < 2) {
      errors.add(valueError);
      continue;
    }
    final bool? parsedValue = _guarBool(body.values[1]);
    if (parsedValue == null) {
      errors.add(valueError);
      continue;
    }
    value = parsedValue;
  }
  return _GuarBoolScan(value: value, errors: errors, hits: hits);
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

class _HideLook {
  const _HideLook({required this.hide, required this.key, required this.exact, required this.body, required this.hit});

  final GuarHide? hide;
  final String key;
  final bool exact;
  final p.CustomBody body;
  final _GuarHit hit;
}

class _HideCollected {
  const _HideCollected({required this.looks});

  final List<_HideLook> looks;
}

({Set<String> values, List<String> errors}) _readHide(String source, p.ParsedLedger parsed) {
  final _HideCollected collected = _collectHide(source, parsed);
  final Set<String> values = <String>{};
  final List<String> errors = <String>[];
  for (final _HideLook look in collected.looks) {
    if (look.hide == null) {
      errors.add('${look.key} is not a ledger hide toggle');
    }
  }
  for (final GuarHide hide in GuarHide.values) {
    final List<_HideLook> mine = <_HideLook>[
      for (final _HideLook look in collected.looks)
        if (look.hide == hide) look,
    ];
    if (mine.isEmpty) {
      continue;
    }
    if (mine.length == 1 && mine.single.exact) {
      values.add(hide.token);
    } else if (mine.length == 1) {
      errors.add(_hideMismatch(hide.optionKey, mine.single.body));
    } else {
      errors.add('${hide.optionKey} expects a single "TRUE"');
    }
  }
  return (values: values, errors: errors);
}

_HideCollected _collectHide(String source, p.ParsedLedger parsed) {
  final List<p.ParsedDirective> directives = switch (parsed) {
    p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives) => directives,
    p.ParsedLedgerErrors() => const <p.ParsedDirective>[],
  };
  final _Text text = _split(source);
  final List<_HideLook> looks = <_HideLook>[];
  for (final p.ParsedDirective directive in directives) {
    final p.DirectiveBody body = directive.body;
    if (body is! p.CustomBody || body.type != 'guar_option') {
      continue;
    }
    final int start = directive.location.linenoBegin - 1;
    final int quotedEnd = start >= 0 && start < text.lines.length ? _spanEnd(text.lines, start) : start;
    final int metaEnd = directive.location.linenoEnd - 1;
    final int end = metaEnd > quotedEnd ? metaEnd : quotedEnd;
    if (body.values.isEmpty || body.values.first is! p.CustomText) {
      continue;
    }
    final String key = (body.values.first as p.CustomText).value;
    final GuarHide? hide = _hideForKey(key);
    if (hide == null && key != 'hide_directives' && !key.startsWith('hide_')) {
      continue;
    }
    looks.add(
      _HideLook(
        hide: hide,
        key: key,
        exact: hide != null && _exactHideTrue(body),
        body: body,
        hit: _GuarHit(start: start, end: end, date: directive.date.toString()),
      ),
    );
  }
  return _HideCollected(looks: looks);
}

GuarHide? _hideForKey(String key) {
  for (final GuarHide hide in GuarHide.values) {
    if (hide.optionKey == key) {
      return hide;
    }
  }
  return null;
}

bool _exactHideTrue(p.CustomBody body) =>
    body.values.length == 2 && body.values[1] is p.CustomText && (body.values[1] as p.CustomText).value == 'TRUE';

String _hideMismatch(String key, p.CustomBody body) {
  if (body.values.length != 2) {
    return '$key expects "TRUE"';
  }
  final String found = switch (body.values[1]) {
    p.CustomText(:final String value) => '"$value"',
    p.CustomBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
    p.CustomAccount(:final p.Account value) => value.name,
    p.CustomCurrency(:final p.Currency value) => value.name,
    p.CustomDate() => 'a date',
    p.CustomNumber() => 'a number',
    p.CustomAmount() => 'an amount',
  };
  return '$key: found $found expected "TRUE"';
}

String _guarBoolLine(String date, String key) => '$date custom "guar_option" "$key" "TRUE"';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
