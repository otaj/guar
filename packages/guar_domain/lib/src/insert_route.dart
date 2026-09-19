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
  final Set<String> tree = _filesInTree(existing, info);
  final String root = info.filename ?? '';
  final ({String filename, int lineno})? match = _matchingInsertEntry(date, _accountsForInsert(body), existing);
  if (match != null) {
    return BeanLocation(filename: match.filename, linenoBegin: match.lineno, linenoEnd: match.lineno);
  }
  final String fallback = _defaultFile(existing, tree) ?? root;
  final int line = _appendLine(fallback, existing, info);
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

({String filename, int lineno})? _matchingInsertEntry(BeanDate date, List<String> accounts, List<Directive> existing) {
  final List<({BeanDate date, String filename, int lineno, RegExp pattern})> rules =
      <({BeanDate date, String filename, int lineno, RegExp pattern})>[
        for (final Directive directive in existing) ?_insertEntryRule(directive),
      ]..sort(
        (
          ({BeanDate date, String filename, int lineno, RegExp pattern}) a,
          ({BeanDate date, String filename, int lineno, RegExp pattern}) b,
        ) => compareBeanDate(b.date, a.date),
      );
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

int _appendLine(String filename, List<Directive> existing, ProcessingInfo info) {
  int last = 0;
  void consider(BeanLocation location) {
    if (location.filename == filename && location.linenoEnd > last) {
      last = location.linenoEnd;
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
  return last == 0 ? 1 : last + 1;
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
