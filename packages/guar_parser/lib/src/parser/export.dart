// Renders a ParsedLedger back to Beancount text, keeping source line numbers.

import 'dart:io';
import 'dart:math' as math;

import '../domain/domain.dart';

String exportLedger(ParsedLedger ledger) {
  return switch (ledger) {
    ParsedLedgerErrors() => throw StateError('cannot export a ledger with parse errors'),
    ParsedLedgerDirectives(:final directives, :final info) => _render(directives, info),
  };
}

void writeExportedLedger(ParsedLedger ledger, File file, {required bool overwrite}) {
  if (file.existsSync()) {
    final existing = file.readAsStringSync();
    if (existing.isNotEmpty && !overwrite) {
      throw StateError('refusing to overwrite ${file.path}');
    }
  }
  file.writeAsStringSync(exportLedger(ledger));
}

String _render(List<ParsedDirective> directives, ProcessingInfo info) {
  final mainName = info.filename ?? '';
  final main = _FileRender();
  final included = <String, _FileRender>{};

  _FileRender bucket(String filename) {
    if (filename == mainName) {
      return main;
    }
    return included.putIfAbsent(filename, _FileRender.new);
  }

  for (final setting in info.optionSettings) {
    bucket(setting.location.filename).place(setting.location.linenoBegin, _optionLine(setting));
  }
  for (final plugin in info.plugin) {
    bucket(plugin.location.filename).place(plugin.location.linenoBegin, _pluginLine(plugin));
  }
  for (final directive in directives) {
    _placeDirective(bucket(directive.location.filename), directive);
  }

  final chunks = <String>[];
  final mainText = main.render();
  if (mainText.isNotEmpty) {
    chunks.add(mainText);
  }
  final seen = <String>{};
  for (final path in info.include) {
    final part = included[path];
    if (part == null) {
      continue;
    }
    seen.add(path);
    final text = part.renderRebased();
    if (text.isNotEmpty) {
      chunks.add(text);
    }
  }
  for (final entry in included.entries) {
    if (seen.contains(entry.key)) {
      continue;
    }
    final text = entry.value.renderRebased();
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
  final begin = directive.location.linenoBegin;
  file.place(begin, _directiveHeader(directive));
  var metaLine = begin + 1;
  var metaIndex = 0;
  if (directive.body case TransactionBody(:final value)) {
    final firstPosting = value.postings.isEmpty ? null : value.postings.first.location.linenoBegin;
    for (final entry in directive.meta.entries) {
      if (firstPosting != null && metaLine >= firstPosting) {
        break;
      }
      file.place(metaLine, '  ${_metaLine(entry)}');
      metaIndex += 1;
      metaLine += 1;
    }
    for (final posting in value.postings) {
      var postingLine = posting.location.linenoBegin;
      file.place(postingLine, _postingLine(posting));
      postingLine += 1;
      for (final entry in posting.meta.entries) {
        file.place(postingLine, '  ${_metaLine(entry)}');
        postingLine += 1;
      }
    }
    if (metaIndex < directive.meta.entries.length) {
      var after = value.postings.isEmpty
          ? begin + 1
          : value.postings.last.location.linenoBegin + 1 + value.postings.last.meta.entries.length;
      for (final entry in directive.meta.entries.skip(metaIndex)) {
        file.place(after, '  ${_metaLine(entry)}');
        after += 1;
      }
    }
    return;
  }
  for (final entry in directive.meta.entries) {
    file.place(metaLine, '  ${_metaLine(entry)}');
    metaLine += 1;
  }
}

class _FileRender {
  final Map<int, String> _lines = {};

  void place(int line, String text) {
    var at = line < 1 ? 1 : line;
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
    final minLine = _lines.keys.reduce(math.min);
    final shifted = <int, String>{};
    for (final entry in _lines.entries) {
      shifted[entry.key - minLine + 1] = entry.value;
    }
    return _join(shifted);
  }

  String _join(Map<int, String> lines) {
    if (lines.isEmpty) {
      return '';
    }
    final last = lines.keys.reduce(math.max);
    final out = <String>[];
    for (var i = 1; i <= last; i++) {
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
  final date = _date(directive.date);
  return switch (directive.body) {
    TransactionBody(:final value) => _transactionHeader(date, value),
    PriceBody(:final currency, :final amount) => '$date price ${currency.name} ${_amount(amount)}',
    BalanceBody(:final account, :final amount, :final tolerance) =>
      tolerance == null
          ? '$date balance ${account.name} ${_amount(amount)}'
          : '$date balance ${account.name} ${amount.number.verbatim} ~ ${tolerance.verbatim} ${amount.currency.name}',
    OpenBody(:final account, :final currencies, :final booking) => [
      '$date open ${account.name}',
      if (currencies.isNotEmpty) currencies.map((c) => c.name).join(','),
      if (booking != null) _quote(_booking(booking)),
    ].join(' '),
    CloseBody(:final account) => '$date close ${account.name}',
    CommodityBody(:final currency) => '$date commodity ${currency.name}',
    PadBody(:final account, :final sourceAccount) => '$date pad ${account.name} ${sourceAccount.name}',
    DocumentBody(:final account, :final filename, :final tags, :final links) => _suffixTags(
      '$date document ${account.name} ${_quote(filename)}',
      tags,
      links,
    ),
    NoteBody(:final account, :final comment, :final tags, :final links) => _suffixTags(
      '$date note ${account.name} ${_quote(comment)}',
      tags,
      links,
    ),
    EventBody(:final name, :final description) => '$date event ${_quote(name)} ${_quote(description)}',
    QueryBody(:final name, :final queryString) => '$date query ${_quote(name)} ${_quote(queryString)}',
    CustomBody(:final type, :final values) => [
      '$date custom ${_quote(type)}',
      for (final value in values) _customValue(value),
    ].join(' '),
  };
}

String _transactionHeader(String date, ParsedTransaction txn) {
  final parts = <String>[_flag(txn.flag)];
  if (txn.payee != null) {
    parts.add(_quote(txn.payee!));
    parts.add(_quote(txn.narration));
  } else if (txn.narration.isNotEmpty) {
    parts.add(_quote(txn.narration));
  }
  return _suffixTags('$date ${parts.join(' ')}', txn.tags, txn.links);
}

String _postingLine(ParsedPosting posting) {
  final parts = <String>[];
  if (posting.flag != null) {
    parts.add(_flag(posting.flag!));
  }
  parts.add(posting.account.name);
  if (posting.units != null) {
    final units = _incomplete(posting.units!);
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
  final parts = <String>[];
  if (cost.numberPer != null) {
    parts.add(cost.numberPer!.verbatim);
  }
  if (cost.numberTotal != null) {
    parts.add('# ${cost.numberTotal!.verbatim}');
  }
  if (cost.currency != null) {
    parts.add(cost.currency!.name);
  }
  final extras = <String>[];
  if (cost.date != null) {
    extras.add(_date(cost.date!));
  }
  if (cost.label != null) {
    extras.add(_quote(cost.label!));
  }
  if (cost.merge) {
    extras.add('*');
  }
  var inner = parts.join(' ');
  if (extras.isNotEmpty) {
    inner = inner.isEmpty ? extras.join(', ') : '$inner, ${extras.join(', ')}';
  }
  return '{$inner}';
}

String _price(ParsedPrice price) {
  final mark = price.isTotal ? '@@' : '@';
  final amount = _incomplete(IncompleteAmount(number: price.number, currency: price.currency));
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
      MetaTag(:final value) => '#${value.name}',
      _ => entry.value == null ? ':' : ': ${_metaValue(entry.value!)}',
    };
  }
  if (entry.value == null) {
    return '${entry.key}:';
  }
  return '${entry.key}: ${_metaValue(entry.value!)}';
}

String _metaValue(MetaValue value) {
  return switch (value) {
    MetaText(:final value) => _quote(value),
    MetaAccount(:final value) => value.name,
    MetaCurrency(:final value) => value.name,
    MetaTag(:final value) => '#${value.name}',
    MetaDate(:final value) => _date(value),
    MetaBoolean(:final value) => value ? 'TRUE' : 'FALSE',
    MetaNumber(:final value) => value.verbatim,
    MetaAmount(:final value) => _amount(value),
  };
}

String _customValue(CustomValue value) {
  return switch (value) {
    CustomText(:final value) => _quote(value),
    CustomAccount(:final value) => value.name,
    CustomDate(:final value) => _date(value),
    CustomBoolean(:final value) => value ? 'TRUE' : 'FALSE',
    CustomNumber(:final value) => value.verbatim,
    CustomAmount(:final value) => _amount(value),
  };
}

String _suffixTags(String head, List<Tag> tags, List<Link> links) {
  final extra = [for (final tag in tags) '#${tag.name}', for (final link in links) '^${link.name}'];
  if (extra.isEmpty) {
    return head;
  }
  return '$head ${extra.join(' ')}';
}

String _flag(Flag flag) {
  return switch (flag) {
    SpecialFlagValue(:final value) => switch (value) {
      SpecialFlag.asterisk => '*',
      SpecialFlag.exclamation => '!',
      SpecialFlag.hash => '#',
      SpecialFlag.ampersand => '&',
      SpecialFlag.question => '?',
      SpecialFlag.percent => '%',
    },
    LetterFlag(:final value) => value,
  };
}

String _booking(BookingMethod method) {
  return switch (method) {
    BookingMethod.strict => 'STRICT',
    BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
    BookingMethod.none => 'NONE',
    BookingMethod.average => 'AVERAGE',
    BookingMethod.fifo => 'FIFO',
    BookingMethod.lifo => 'LIFO',
    BookingMethod.hifo => 'HIFO',
  };
}

String _date(BeanDate date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _quote(String value) => '"$value"';
