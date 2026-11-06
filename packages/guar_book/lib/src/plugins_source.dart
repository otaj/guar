// Read and write root-file plugin directives, keeping their order.

import 'package:guar_parser/guar_parser.dart' as p;

class LedgerPlugin {
  const LedgerPlugin({required this.name, this.config});

  final String name;
  final String? config;
}

List<LedgerPlugin> readLedgerPlugins(String source) => readLedgerPluginsFrom(_parse(source));

List<LedgerPlugin> readLedgerPluginsFrom(p.ParsedLedger parsed) => <LedgerPlugin>[
  for (final p.Plugin plugin in parsed.info.plugin) LedgerPlugin(name: plugin.name, config: plugin.config),
];

String writeLedgerPlugins(String source, List<LedgerPlugin> plugins, {p.ParsedLedger? parsed}) {
  final List<String> rendered = <String>[
    for (final LedgerPlugin plugin in plugins) ..._pluginLines(plugin),
  ];
  final p.ParsedLedger ledger = parsed ?? _parse(source);
  final _Text text = _split(source);
  final List<({int end, int start})> spans = <({int end, int start})>[];
  for (final p.Plugin plugin in ledger.info.plugin) {
    final int start = plugin.location.linenoBegin - 1;
    if (start < 0 || start >= text.lines.length) continue;
    spans.add((start: start, end: _spanEnd(text.lines, start)));
  }
  spans.sort((({int end, int start}) a, ({int end, int start}) b) => a.start.compareTo(b.start));
  if (rendered.isEmpty && spans.isEmpty) return source;
  final List<String> lines = List<String>.of(text.lines);
  final int insertAt = spans.isEmpty ? _afterOptions(ledger, text) : spans.first.start;
  for (final ({int end, int start}) span in spans.reversed) {
    if (span.start >= lines.length) continue;
    final int end = span.end >= lines.length ? lines.length - 1 : span.end;
    lines.removeRange(span.start, end + 1);
  }
  lines.insertAll(insertAt > lines.length ? lines.length : insertAt, rendered);
  final bool trailing = source.isEmpty ? rendered.isNotEmpty : text.trailing;
  return _join(lines, text.separator, trailing);
}

List<String> _pluginLines(LedgerPlugin plugin) {
  final String? config = plugin.config;
  final String rendered = config == null
      ? 'plugin ${_quote(plugin.name)}'
      : 'plugin ${_quote(plugin.name)} ${_quote(config)}';
  return rendered.split('\n');
}

String _quote(String value) {
  if (value.contains('"')) {
    throw const FormatException('Quotes cannot be stored in a plugin configuration');
  }
  return '"$value"';
}

int _afterOptions(p.ParsedLedger parsed, _Text text) {
  int at = 0;
  for (final p.OptionSetting setting in parsed.info.optionSettings) {
    final int start = setting.location.linenoBegin - 1;
    if (start < 0 || start >= text.lines.length) continue;
    final int end = _spanEnd(text.lines, start);
    if (end + 1 > at) at = end + 1;
  }
  return at;
}

p.ParsedLedger _parse(String source) => const p.BeancountParser().parse(source, followIncludes: false, recover: true);

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
    if (ch == '"') open = !open;
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
  if (source.isEmpty) return const _Text(lines: <String>[], separator: '\n', trailing: false);
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
    if (cr && i + 1 < source.length && source.codeUnitAt(i + 1) == 10) i += 1;
  }
  final bool trailing = source.endsWith('\n') || source.endsWith('\r');
  if (!trailing) lines.add(current.toString());
  return _Text(lines: lines, separator: separator, trailing: trailing);
}

String _join(List<String> lines, String separator, bool trailing) {
  if (lines.isEmpty) return '';
  final String body = lines.join(separator);
  return trailing ? '$body$separator' : body;
}
