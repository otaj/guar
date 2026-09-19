// Destination file for a directive created in memory (insert-entry / default-file / root).

import 'date.dart';
import 'directive.dart';
import 'location.dart';
import 'options.dart';
import 'origin.dart';

BeanLocation insertLocation({
  required BeanDate date,
  required DirectiveBody body,
  required List<Directive> existing,
  required ProcessingInfo info,
}) {
  final tree = _filesInTree(existing, info);
  final root = info.filename ?? '';
  final match = _matchingInsertEntry(date, _accountsForInsert(body), existing);
  if (match != null) {
    return BeanLocation(filename: match.filename, linenoBegin: match.lineno, linenoEnd: match.lineno);
  }
  final fallback = _defaultFile(existing, tree) ?? root;
  final line = _appendLine(fallback, existing, info);
  return BeanLocation(filename: fallback, linenoBegin: line, linenoEnd: line);
}

Origin insertOrigin({
  required BeanDate date,
  required DirectiveBody body,
  required List<Directive> existing,
  required ProcessingInfo info,
}) => Origin.source(insertLocation(date: date, body: body, existing: existing, info: info));

BeanLocation optionPluginLocation(ProcessingInfo info) {
  final root = info.filename ?? '';
  return BeanLocation(filename: root, linenoBegin: 1, linenoEnd: 1);
}

List<String> _accountsForInsert(DirectiveBody body) {
  return switch (body) {
    TransactionBody(:final value) => [for (final posting in value.postings.reversed) posting.account.name],
    PadBody(:final account, :final sourceAccount) => [account.name, sourceAccount.name],
    OpenBody(:final account) ||
    CloseBody(:final account) ||
    BalanceBody(:final account) ||
    NoteBody(:final account) ||
    DocumentBody(:final account) ||
    BudgetBody(:final account) ||
    BudgetOffBody(:final account) => [account.name],
    CustomBody(:final values) => [
      for (final value in values)
        if (value is CustomAccount) value.value.name,
    ],
    PriceBody() || CommodityBody() || EventBody() || QueryBody() => const [],
  };
}

({String filename, int lineno})? _matchingInsertEntry(BeanDate date, List<String> accounts, List<Directive> existing) {
  final rules = [for (final directive in existing) ?_insertEntryRule(directive)]
    ..sort((a, b) => compareBeanDate(b.date, a.date));
  for (final account in accounts) {
    for (final rule in rules) {
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
  final body = directive.body as CustomBody;
  if (body.type != 'fava-option' || body.values.length < 2) {
    return null;
  }
  final key = body.values[0];
  final value = body.values[1];
  if (key is! CustomText || key.value != 'insert-entry' || value is! CustomText) {
    return null;
  }
  final origin = directive.origin;
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
  for (final directive in existing) {
    if (directive.body is! CustomBody) {
      continue;
    }
    final body = directive.body as CustomBody;
    if (body.type != 'fava-option' || body.values.isEmpty) {
      continue;
    }
    final key = body.values[0];
    if (key is! CustomText || key.value != 'default-file') {
      continue;
    }
    final origin = directive.origin;
    if (origin is! SourceOrigin) {
      continue;
    }
    final relative = body.values.length > 1 && body.values[1] is CustomText ? (body.values[1] as CustomText).value : '';
    final resolved = _resolveAgainst(origin.location.filename, relative);
    final inTree = _treeMember(resolved, tree);
    if (inTree != null) {
      target = inTree;
    }
  }
  return target;
}

int _appendLine(String filename, List<Directive> existing, ProcessingInfo info) {
  var last = 0;
  void consider(BeanLocation location) {
    if (location.filename == filename && location.linenoEnd > last) {
      last = location.linenoEnd;
    }
  }

  for (final setting in info.optionSettings) {
    consider(setting.location);
  }
  for (final plugin in info.plugin) {
    consider(plugin.location);
  }
  for (final directive in existing) {
    if (directive.origin case SourceOrigin(:final location)) {
      consider(location);
    }
  }
  return last == 0 ? 1 : last + 1;
}

Set<String> _filesInTree(List<Directive> existing, ProcessingInfo info) {
  final files = <String>{};
  final root = info.filename;
  if (root != null && root.isNotEmpty) {
    files.add(root);
  }
  files.addAll(info.include);
  for (final directive in existing) {
    if (directive.origin case SourceOrigin(:final location) when location.filename.isNotEmpty) {
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
  final normalized = fromFile.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash < 0) {
    return relative;
  }
  return '${normalized.substring(0, slash)}/$relative';
}

String? _treeMember(String path, Set<String> tree) {
  if (tree.contains(path)) {
    return path;
  }
  final normalized = path.replaceAll('\\', '/');
  for (final file in tree) {
    if (file.replaceAll('\\', '/') == normalized) {
      return file;
    }
  }
  return null;
}
