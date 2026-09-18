// Discover document files under option document roots.

import 'dart:io';

import 'package:guar_domain/guar_domain.dart';

import '../stage_result.dart';

final _docName = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\.(.*)$');

StageResult applyDocuments(List<Directive> directives, LedgerOptions options, ProcessingInfo info) {
  final roots = options.documents;
  if (roots.isEmpty) {
    return StageResult(directives: directives);
  }

  final accounts = <String>{};
  for (final directive in directives) {
    final body = directive.body;
    if (body is OpenBody) {
      accounts.add(body.account.name);
    }
  }

  final added = <Directive>[];
  final errors = <ProcessingError>[];
  final base = info.filename == null || info.filename!.isEmpty
      ? Directory.current.path
      : File(info.filename!).parent.path;

  for (final root in roots) {
    final dir = Directory(root.startsWith('/') ? root : '$base/$root');
    if (!dir.existsSync()) {
      continue;
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      final match = _docName.firstMatch(name);
      if (match == null) continue;
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      // Account path is relative directories under the documents root.
      final relative = entity.path.substring(dir.path.length).replaceAll('\\', '/');
      final parts = relative.split('/')..removeWhere((p) => p.isEmpty);
      if (parts.length < 2) continue;
      final accountName = parts.sublist(0, parts.length - 1).join(':');
      if (!accounts.contains(accountName)) {
        continue;
      }
      added.add(
        Directive(
          origin: const Origin.generated(),
          date: BeanDate(year: year, month: month, day: day),
          body: DirectiveBody.document(
            account: Account(name: accountName, type: AccountType.assets),
            filename: entity.path,
          ),
        ),
      );
    }
  }

  final merged = [...directives, ...added]..sort(_directiveSort);
  return StageResult(directives: merged, errors: errors);
}

int _directiveSort(Directive a, Directive b) {
  final byDate = compareBeanDate(a.date, b.date);
  if (byDate != 0) return byDate;
  return _typeOrder(a.body).compareTo(_typeOrder(b.body));
}

int _typeOrder(DirectiveBody body) => switch (body) {
  OpenBody() => 0,
  CloseBody() => 1,
  CommodityBody() => 2,
  PadBody() => 3,
  BalanceBody() => 4,
  TransactionBody() => 5,
  NoteBody() => 6,
  EventBody() => 7,
  QueryBody() => 8,
  PriceBody() => 9,
  DocumentBody() => 10,
  CustomBody() || BudgetBody() => 11,
};
