// Discover document files under option document roots.

import 'dart:io';

import 'package:guar_book/src/stage_result.dart';
import 'package:guar_domain/guar_domain.dart';

final RegExp _docName = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\.(.*)$');

StageResult applyDocuments(List<Directive> directives, LedgerOptions options, ProcessingInfo info) {
  final List<String> roots = options.documents;
  if (roots.isEmpty) {
    return StageResult(directives: directives);
  }

  final Set<String> accounts = <String>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is OpenBody) {
      accounts.add(body.account.name);
    }
  }

  final List<Directive> added = <Directive>[];
  final List<ProcessingError> errors = <ProcessingError>[];
  final String base = info.filename == null || info.filename!.isEmpty
      ? Directory.current.path
      : File(info.filename!).parent.path;

  for (final String root in roots) {
    final Directory dir = Directory(root.startsWith('/') ? root : '$base/$root');
    if (!dir.existsSync()) {
      continue;
    }
    for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      final RegExpMatch? match = _docName.firstMatch(name);
      if (match == null) continue;
      final int year = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      final int day = int.parse(match.group(3)!);
      // Account path is relative directories under the documents root.
      final String relative = entity.path.substring(dir.path.length).replaceAll(r'\', '/');
      final List<String> parts = relative.split('/')..removeWhere((String p) => p.isEmpty);
      if (parts.length < 2) continue;
      final String accountName = parts.sublist(0, parts.length - 1).join(':');
      if (!accounts.contains(accountName)) {
        continue;
      }
      added.add(
        Directive(
          origin: insertOrigin(
            date: BeanDate(year: year, month: month, day: day),
            body: DirectiveBody.document(
              account: Account(name: accountName, type: AccountType.assets),
              filename: entity.path,
            ),
            existing: directives,
            info: info,
          ),
          date: BeanDate(year: year, month: month, day: day),
          body: DirectiveBody.document(
            account: Account(name: accountName, type: AccountType.assets),
            filename: entity.path,
          ),
        ),
      );
    }
  }

  final List<Directive> merged = <Directive>[...directives, ...added]..sort(_directiveSort);
  return StageResult(directives: merged, errors: errors);
}

int _directiveSort(Directive a, Directive b) {
  final int byDate = compareBeanDate(a.date, b.date);
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
  CustomBody() || BudgetBody() || BudgetOffBody() => 11,
};
