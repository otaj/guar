// Destination file for a directive created in memory (insert-entry / default-file / root).

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/date.dart';
import 'package:guar_domain/src/directive.dart';
import 'package:guar_domain/src/location.dart';
import 'package:guar_domain/src/options.dart';
import 'package:guar_domain/src/origin.dart';
import 'package:guar_domain/src/posting.dart';
import 'package:guar_domain/src/transaction.dart';

BeanLocation insertLocation({
  required BeanDate date,
  required DirectiveBody body,
  required List<Directive> existing,
  required ProcessingInfo info,
}) {
  final _InsertContext context = _contextFor(existing, info);
  final String root = info.filename ?? '';
  final ({String filename, int lineno})? match = _matchingInsertEntry(date, _accountsForInsert(body), context.rules);
  if (match != null) {
    return BeanLocation(filename: match.filename, linenoBegin: match.lineno, linenoEnd: match.lineno);
  }
  final String fallback = context.defaultFile ?? root;
  final int last = context.lastLines[fallback] ?? 0;
  final int line = last == 0 ? 1 : last + 1;
  return BeanLocation(filename: fallback, linenoBegin: line, linenoEnd: line);
}

Origin insertOrigin({
  required BeanDate date,
  required DirectiveBody body,
  required List<Directive> existing,
  required ProcessingInfo info,
}) => Origin.source(insertLocation(date: date, body: body, existing: existing, info: info));

BeanLocation optionPluginLocation(ProcessingInfo info) {
  final String root = info.filename ?? '';
  return BeanLocation(filename: root, linenoBegin: 1, linenoEnd: 1);
}

List<String> _accountsForInsert(DirectiveBody body) => switch (body) {
  TransactionBody(:final Transaction value) => <String>[
    for (final Posting posting in value.postings.reversed) posting.account.name,
  ],
  PadBody(:final Account account, :final Account sourceAccount) => <String>[account.name, sourceAccount.name],
  OpenBody(:final Account account) ||
  CloseBody(:final Account account) ||
  BalanceBody(:final Account account) ||
  NoteBody(:final Account account) ||
  DocumentBody(:final Account account) ||
  BudgetBody(:final Account account) ||
  BudgetOffBody(:final Account account) => <String>[account.name],
  CustomBody(:final List<CustomValue> values) => <String>[
    for (final CustomValue value in values)
      if (value is CustomAccount) value.value.name,
  ],
  PriceBody() || CommodityBody() || EventBody() || QueryBody() => const <String>[],
};

({String filename, int lineno})? _matchingInsertEntry(BeanDate date, List<String> accounts, List<_InsertRule> rules) {
  for (final String account in accounts) {
    for (final ({BeanDate date, String filename, int lineno, RegExp pattern}) rule in rules) {
      if (compareBeanDate(rule.date, date) >= 0) {
        continue;
      }
      if (rule.pattern.matchAsPrefix(account) != null) {
        return (filename: rule.filename, lineno: rule.lineno);
      }
    }
  }
  return null;
}

({BeanDate date, RegExp pattern, String filename, int lineno})? _insertEntryRule(Directive directive) {
  if (directive.body is! CustomBody) {
    return null;
  }
  final CustomBody body = directive.body as CustomBody;
  if (body.type != 'fava-option' || body.values.length < 2) {
    return null;
  }
  final CustomValue key = body.values[0];
  final CustomValue value = body.values[1];
  if (key is! CustomText || key.value != 'insert-entry' || value is! CustomText) {
    return null;
  }
  final Origin origin = directive.origin;
  if (origin is! SourceOrigin) {
    return null;
  }
  final RegExp pattern;
  try {
    pattern = RegExp(value.value);
  } on FormatException {
    return null;
  }
  return (
    date: directive.date,
    pattern: pattern,
    filename: origin.location.filename,
    lineno: origin.location.linenoBegin,
  );
}

// Insert routing scans the whole directive list per generated entry; stages call this
// once per entry with the same input list, so the scans are cached by list identity.
// shortcut: keyed on identity, a stage that mutates its input list between inserts must clear it.
typedef _InsertRule = ({BeanDate date, String filename, int lineno, RegExp pattern});

class _InsertContext {
  const _InsertContext(this.existing, this.info, this.rules, this.defaultFile, this.lastLines);

  final List<Directive> existing;
  final ProcessingInfo info;
  final List<_InsertRule> rules;
  final String? defaultFile;
  final Map<String, int> lastLines;
}

_InsertContext? _insertContextCache;

_InsertContext _contextFor(List<Directive> existing, ProcessingInfo info) {
  final _InsertContext? cached = _insertContextCache;
  if (cached != null && identical(cached.existing, existing) && identical(cached.info, info)) {
    return cached;
  }
  final Set<String> tree = _filesInTree(existing, info);
  final List<_InsertRule> rules = <_InsertRule>[
    for (final Directive directive in existing) ?_insertEntryRule(directive),
  ]..sort((_InsertRule a, _InsertRule b) => compareBeanDate(b.date, a.date));
  final Map<String, int> lastLines = _lastLines(existing, info);
  return _insertContextCache = _InsertContext(existing, info, rules, _defaultFile(existing, tree), lastLines);
}

Map<String, int> _lastLines(List<Directive> existing, ProcessingInfo info) {
  final Map<String, int> lastLines = <String, int>{};
  void consider(BeanLocation location) {
    final int previous = lastLines[location.filename] ?? 0;
    if (location.linenoEnd > previous) {
      lastLines[location.filename] = location.linenoEnd;
    }
  }

  for (final OptionSetting setting in info.optionSettings) {
    consider(setting.location);
  }
  for (final Plugin plugin in info.plugin) {
    consider(plugin.location);
  }
  for (final Directive directive in existing) {
    if (directive.origin case SourceOrigin(:final BeanLocation location)) {
      consider(location);
    }
  }
  return lastLines;
}

String? _defaultFile(List<Directive> existing, Set<String> tree) {
  String? target;
  for (final Directive directive in existing) {
    if (directive.body is! CustomBody) {
      continue;
    }
    final CustomBody body = directive.body as CustomBody;
    if (body.type != 'fava-option' || body.values.isEmpty) {
      continue;
    }
    final CustomValue key = body.values[0];
    if (key is! CustomText || key.value != 'default-file') {
      continue;
    }
    final Origin origin = directive.origin;
    if (origin is! SourceOrigin) {
      continue;
    }
    final String relative = body.values.length > 1 && body.values[1] is CustomText
        ? (body.values[1] as CustomText).value
        : '';
    final String resolved = _resolveAgainst(origin.location.filename, relative);
    final String? inTree = _treeMember(resolved, tree);
    if (inTree != null) {
      target = inTree;
    }
  }
  return target;
}

Set<String> _filesInTree(List<Directive> existing, ProcessingInfo info) {
  final Set<String> files = <String>{};
  final String? root = info.filename;
  if (root != null && root.isNotEmpty) {
    files.add(root);
  }
  files.addAll(info.include);
  for (final Directive directive in existing) {
    if (directive.origin case SourceOrigin(:final BeanLocation location) when location.filename.isNotEmpty) {
      files.add(location.filename);
    }
  }
  return files;
}

String _resolveAgainst(String fromFile, String relative) {
  if (relative.isEmpty) {
    return fromFile;
  }
  if (relative.startsWith('/')) {
    return relative;
  }
  final String normalized = fromFile.replaceAll(r'\', '/');
  final int slash = normalized.lastIndexOf('/');
  if (slash < 0) {
    return relative;
  }
  return '${normalized.substring(0, slash)}/$relative';
}

String? _treeMember(String path, Set<String> tree) {
  if (tree.contains(path)) {
    return path;
  }
  final String normalized = path.replaceAll(r'\', '/');
  for (final String file in tree) {
    if (file.replaceAll(r'\', '/') == normalized) {
      return file;
    }
  }
  return null;
}
