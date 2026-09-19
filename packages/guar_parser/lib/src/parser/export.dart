// Renders a ParsedLedger back to Beancount text, keeping source line numbers.

import 'dart:io';
import 'dart:math' as math;

import 'package:guar_parser/src/domain/domain.dart';

String exportLedger(ParsedLedger ledger) => switch (ledger) {
  ParsedLedgerErrors() => throw StateError('cannot export a ledger with parse errors'),
  ParsedLedgerDirectives(:final List<ParsedDirective> directives, :final ProcessingInfo info) => _render(
    directives,
    info,
  ),
};

void writeExportedLedger(ParsedLedger ledger, File file, {required bool overwrite}) {
  if (file.existsSync()) {
    final String existing = file.readAsStringSync();
    if (existing.isNotEmpty && !overwrite) {
      throw StateError('refusing to overwrite ${file.path}');
    }
  }
  file.writeAsStringSync(exportLedger(ledger));
}

String _render(List<ParsedDirective> directives, ProcessingInfo info) {
  final String mainName = info.filename ?? '';
  final _FileRender main = _FileRender();
  final Map<String, _FileRender> included = <String, _FileRender>{};

  _FileRender bucket(String filename) {
    if (filename == mainName) {
      return main;
    }
    return included.putIfAbsent(filename, _FileRender.new);
  }

  for (final OptionSetting setting in info.optionSettings) {
    bucket(setting.location.filename).place(setting.location.linenoBegin, _optionLine(setting));
  }
  for (final Plugin plugin in info.plugin) {
    bucket(plugin.location.filename).place(plugin.location.linenoBegin, _pluginLine(plugin));
  }
  for (final ParsedDirective directive in directives) {
    _placeDirective(bucket(directive.location.filename), directive);
  }

  final List<String> chunks = <String>[];
  final String mainText = main.render();
  if (mainText.isNotEmpty) {
    chunks.add(mainText);
  }
  final Set<String> seen = <String>{};
  for (final String path in info.include) {
    final _FileRender? part = included[path];
    if (part == null) {
      continue;
    }
    seen.add(path);
    final String text = part.renderRebased();
    if (text.isNotEmpty) {
      chunks.add(text);
    }
  }
  for (final MapEntry<String, _FileRender> entry in included.entries) {
    if (seen.contains(entry.key)) {
      continue;
    }
    final String text = entry.value.renderRebased();
    if (text.isNotEmpty) {
      chunks.add(text);
    }
  }
  if (chunks.isEmpty) {
    return '';
  }
  return chunks.join('\n');
}

void _placeDirective(_FileRender file, ParsedDirective directive) {
  final int begin = directive.location.linenoBegin;
  file.place(begin, _directiveHeader(directive));
  int metaLine = begin + 1;
  int metaIndex = 0;
  if (directive.body case TransactionBody(:final ParsedTransaction value)) {
    final int? firstPosting = value.postings.isEmpty ? null : value.postings.first.location.linenoBegin;
    for (final MetaEntry entry in directive.meta.entries) {
      if (firstPosting != null && metaLine >= firstPosting) {
        break;
      }
      file.place(metaLine, '  ${_metaLine(entry)}');
      metaIndex += 1;
      metaLine += 1;
    }
    for (final ParsedPosting posting in value.postings) {
      int postingLine = posting.location.linenoBegin;
      file.place(postingLine, _postingLine(posting));
      postingLine += 1;
      for (final MetaEntry entry in posting.meta.entries) {
        file.place(postingLine, '  ${_metaLine(entry)}');
        postingLine += 1;
      }
    }
    if (metaIndex < directive.meta.entries.length) {
      int after = value.postings.isEmpty
          ? begin + 1
          : value.postings.last.location.linenoBegin + 1 + value.postings.last.meta.entries.length;
      for (final MetaEntry entry in directive.meta.entries.skip(metaIndex)) {
        file.place(after, '  ${_metaLine(entry)}');
        after += 1;
      }
    }
    return;
  }
  for (final MetaEntry entry in directive.meta.entries) {
    file.place(metaLine, '  ${_metaLine(entry)}');
    metaLine += 1;
  }
}

class _FileRender {
  final Map<int, String> _lines = <int, String>{};

  void place(int line, String text) {
    int at = line < 1 ? 1 : line;
    while (_lines.containsKey(at)) {
      at += 1;
    }
    _lines[at] = text;
  }

  String render() => _join(_lines);

  String renderRebased() {
    if (_lines.isEmpty) {
      return '';
    }
    final int minLine = _lines.keys.reduce(math.min);
    final Map<int, String> shifted = <int, String>{};
    for (final MapEntry<int, String> entry in _lines.entries) {
      shifted[entry.key - minLine + 1] = entry.value;
    }
    return _join(shifted);
  }

  String _join(Map<int, String> lines) {
    if (lines.isEmpty) {
      return '';
    }
    final int last = lines.keys.reduce(math.max);
    final List<String> out = <String>[];
    for (int i = 1; i <= last; i++) {
      out.add(lines[i] ?? '');
    }
    return '${out.join('\n')}\n';
  }
}

String _optionLine(OptionSetting setting) => 'option ${_quote(setting.key)} ${_quote(setting.value)}';

String _pluginLine(Plugin plugin) {
  if (plugin.config == null) {
    return 'plugin ${_quote(plugin.name)}';
  }
  return 'plugin ${_quote(plugin.name)} ${_quote(plugin.config!)}';
}

String _directiveHeader(ParsedDirective directive) {
  final String date = _date(directive.date);
  return switch (directive.body) {
    TransactionBody(:final ParsedTransaction value) => _transactionHeader(date, value),
    PriceBody(:final Currency currency, :final Amount amount) => '$date price ${currency.name} ${_amount(amount)}',
    BalanceBody(:final Account account, :final Amount amount, :final BeanNumber? tolerance) =>
      tolerance == null
          ? '$date balance ${account.name} ${_amount(amount)}'
          : '$date balance ${account.name} ${amount.number.verbatim} ~ ${tolerance.verbatim} ${amount.currency.name}',
    OpenBody(:final Account account, :final List<Currency> currencies, :final BookingMethod? booking) => <String>[
      '$date open ${account.name}',
      if (currencies.isNotEmpty) currencies.map((Currency c) => c.name).join(','),
      if (booking != null) _quote(_booking(booking)),
    ].join(' '),
    CloseBody(:final Account account) => '$date close ${account.name}',
    CommodityBody(:final Currency currency) => '$date commodity ${currency.name}',
    PadBody(:final Account account, :final Account sourceAccount) => '$date pad ${account.name} ${sourceAccount.name}',
    DocumentBody(:final Account account, :final String filename, :final List<Tag> tags, :final List<Link> links) =>
      _suffixTags(
        '$date document ${account.name} ${_quote(filename)}',
        tags,
        links,
      ),
    NoteBody(:final Account account, :final String comment, :final List<Tag> tags, :final List<Link> links) =>
      _suffixTags(
        '$date note ${account.name} ${_quote(comment)}',
        tags,
        links,
      ),
    EventBody(:final String name, :final String description) => '$date event ${_quote(name)} ${_quote(description)}',
    QueryBody(:final String name, :final String queryString) => '$date query ${_quote(name)} ${_quote(queryString)}',
    CustomBody(:final String type, :final List<CustomValue> values) => <String>[
      '$date custom ${_quote(type)}',
      for (final CustomValue value in values) _customValue(value),
    ].join(' '),
  };
}

String _transactionHeader(String date, ParsedTransaction txn) {
  final List<String> parts = <String>[_flag(txn.flag)];
  if (txn.payee != null) {
    parts
      ..add(_quote(txn.payee!))
      ..add(_quote(txn.narration));
  } else if (txn.narration.isNotEmpty) {
    parts.add(_quote(txn.narration));
  }
  return _suffixTags('$date ${parts.join(' ')}', txn.tags, txn.links);
}

String _postingLine(ParsedPosting posting) {
  final List<String> parts = <String>[];
  if (posting.flag != null) {
    parts.add(_flag(posting.flag!));
  }
  parts.add(posting.account.name);
  if (posting.units != null) {
    final String units = _incomplete(posting.units!);
    if (units.isNotEmpty) {
      parts.add(units);
    }
  }
  if (posting.cost != null) {
    parts.add(_cost(posting.cost!));
  }
  if (posting.price != null) {
    parts.add(_price(posting.price!));
  }
  return '  ${parts.join(' ')}';
}

String _cost(ParsedCost cost) {
  final List<String> parts = <String>[];
  if (cost.numberPer != null) {
    parts.add(cost.numberPer!.verbatim);
  }
  if (cost.numberTotal != null) {
    parts.add('# ${cost.numberTotal!.verbatim}');
  }
  if (cost.currency != null) {
    parts.add(cost.currency!.name);
  }
  final List<String> extras = <String>[];
  if (cost.date != null) {
    extras.add(_date(cost.date!));
  }
  if (cost.label != null) {
    extras.add(_quote(cost.label!));
  }
  if (cost.merge) {
    extras.add('*');
  }
  String inner = parts.join(' ');
  if (extras.isNotEmpty) {
    inner = inner.isEmpty ? extras.join(', ') : '$inner, ${extras.join(', ')}';
  }
  return '{$inner}';
}

String _price(ParsedPrice price) {
  final String mark = price.isTotal ? '@@' : '@';
  final String amount = _incomplete(IncompleteAmount(number: price.number, currency: price.currency));
  return amount.isEmpty ? mark : '$mark $amount';
}

String _incomplete(IncompleteAmount amount) {
  if (amount.number != null && amount.currency != null) {
    return '${amount.number!.verbatim} ${amount.currency!.name}';
  }
  if (amount.number != null) {
    return amount.number!.verbatim;
  }
  if (amount.currency != null) {
    return amount.currency!.name;
  }
  return '';
}

String _amount(Amount amount) => '${amount.number.verbatim} ${amount.currency.name}';

String _metaLine(MetaEntry entry) {
  if (entry.key.isEmpty) {
    return switch (entry.value) {
      MetaTag(:final Tag value) => '#${value.name}',
      _ => entry.value == null ? ':' : ': ${_metaValue(entry.value!)}',
    };
  }
  if (entry.value == null) {
    return '${entry.key}:';
  }
  return '${entry.key}: ${_metaValue(entry.value!)}';
}

String _metaValue(MetaValue value) => switch (value) {
  MetaText(:final String value) => _quote(value),
  MetaAccount(:final Account value) => value.name,
  MetaCurrency(:final Currency value) => value.name,
  MetaTag(:final Tag value) => '#${value.name}',
  MetaDate(:final BeanDate value) => _date(value),
  MetaBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
  MetaNumber(:final BeanNumber value) => value.verbatim,
  MetaAmount(:final Amount value) => _amount(value),
};

String _customValue(CustomValue value) => switch (value) {
  CustomText(:final String value) => _quote(value),
  CustomAccount(:final Account value) => value.name,
  CustomDate(:final BeanDate value) => _date(value),
  CustomBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
  CustomNumber(:final BeanNumber value) => value.verbatim,
  CustomAmount(:final Amount value) => _amount(value),
  CustomCurrency(:final Currency value) => value.name,
};

String _suffixTags(String head, List<Tag> tags, List<Link> links) {
  final List<String> extra = <String>[
    for (final Tag tag in tags) '#${tag.name}',
    for (final Link link in links) '^${link.name}',
  ];
  if (extra.isEmpty) {
    return head;
  }
  return '$head ${extra.join(' ')}';
}

String _flag(Flag flag) => switch (flag) {
  SpecialFlagValue(:final SpecialFlag value) => switch (value) {
    SpecialFlag.asterisk => '*',
    SpecialFlag.exclamation => '!',
    SpecialFlag.hash => '#',
    SpecialFlag.ampersand => '&',
    SpecialFlag.question => '?',
    SpecialFlag.percent => '%',
  },
  LetterFlag(:final String value) => value,
};

String _booking(BookingMethod method) => switch (method) {
  BookingMethod.strict => 'STRICT',
  BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
  BookingMethod.none => 'NONE',
  BookingMethod.average => 'AVERAGE',
  BookingMethod.fifo => 'FIFO',
  BookingMethod.lifo => 'LIFO',
  BookingMethod.hifo => 'HIFO',
};

String _date(BeanDate date) => '$date';

String _quote(String value) => '"$value"';
