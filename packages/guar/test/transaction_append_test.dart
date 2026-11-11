// Appending a transaction validates through booking, then writes the target file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_engine.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_domain/guar_domain.dart';

Directory _tempLedger() {
  final Directory dir = Directory.systemTemp.createTempSync('guar_append');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('prepare books directives from included files', () async {
    final Directory dir = _tempLedger();
    Directory('${dir.path}/2026').createSync();
    File('${dir.path}/ledger.beancount').writeAsStringSync('include "2026/main.beancount"\n');
    File(
      '${dir.path}/2026/main.beancount',
    ).writeAsStringSync('2026-11-01 * "Include" "X"\n  Expenses:Food  1 USD\n  Assets:Cash\n');

    final LedgerSnapshot snapshot = await LedgerEngine().prepare(
      'include "2026/main.beancount"\n',
      '${dir.path}/ledger.beancount',
    );
    expect(snapshot.booked.ledger, isA<LedgerDirectives>());
  });

  test('appendTransaction accepts a balanced transaction and elides one leg', () async {
    final Directory dir = _tempLedger();
    final LedgerEngine engine = LedgerEngine();
    const String source = '2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\n';
    expect(
      await engine.appendTransaction(
        source,
        '${dir.path}/ledger.beancount',
        '${dir.path}/ledger.beancount',
        '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash\n',
      ),
      isA<AppendOk>(),
    );
  });

  test('appendTransaction rejects an unbalanced transaction with an error in the snippet', () async {
    final Directory dir = _tempLedger();
    final LedgerEngine engine = LedgerEngine();
    const String source = '2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\n';
    final AppendOutcome outcome = await engine.appendTransaction(
      source,
      '${dir.path}/ledger.beancount',
      '${dir.path}/ledger.beancount',
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash  1.00 USD\n',
    );
    expect(outcome, isA<AppendFailed>());
    expect((outcome as AppendFailed).errors, isNotEmpty);
  });

  test('session addTransaction writes the root file and refreshes the ledger', () async {
    final Directory dir = _tempLedger();
    final String path = '${dir.path}/ledger.beancount';
    File(path).writeAsStringSync('2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\n');
    final _PathDocuments documents = _PathDocuments(path, File(path).readAsStringSync());
    final LedgerSession session = LedgerSession(documents);
    addTearDown(session.dispose);
    await session.load();

    await session.addTransaction(
      path,
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash\n',
    );
    expect(session.error, isNull);
    expect(
      documents.files[path],
      '2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\n'
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash\n',
    );
    final LedgerSnapshot? snapshot = session.snapshot;
    expect(snapshot?.booked.ledger, isA<LedgerDirectives>());
  });

  test('session addTransaction writes an included file', () async {
    final Directory dir = _tempLedger();
    final String root = '${dir.path}/ledger.beancount';
    final String included = '${dir.path}/2026.beancount';
    File(root).writeAsStringSync(
      '2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\ninclude "2026.beancount"\n',
    );
    File(included).writeAsStringSync('');
    final _PathDocuments documents = _PathDocuments(root, File(root).readAsStringSync());
    final LedgerSession session = LedgerSession(documents);
    addTearDown(session.dispose);
    await session.load();

    await session.addTransaction(
      included,
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash\n',
    );
    expect(session.error, isNull);
    expect(
      File(included).readAsStringSync(),
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash\n',
    );
    expect(documents.files[root], File(root).readAsStringSync());
  });

  test('validateTransaction reports balance errors', () async {
    final Directory dir = _tempLedger();
    final String path = '${dir.path}/ledger.beancount';
    File(path).writeAsStringSync('2026-11-01 open Assets:Cash\n2026-11-01 open Expenses:Food\n');
    final LedgerSession session = LedgerSession(_PathDocuments(path, File(path).readAsStringSync()));
    addTearDown(session.dispose);
    await session.load();

    final List<String> errors = await session.validateTransaction(
      path,
      '2026-11-02 * "Grocer" "Lunch"\n  Expenses:Food  12.30 USD\n  Assets:Cash  1.00 USD\n',
    );
    expect(errors, isNotEmpty);
  });
}

class _PathDocuments implements LedgerDocuments {
  _PathDocuments(this.path, String text) : files = <String, String>{path: text};

  final String path;
  final Map<String, String> files;

  @override
  Future<LedgerDocument?> current() async => LedgerDocument(uri: path, displayName: path);

  @override
  Future<LedgerDocument?> openExisting() async => null;

  @override
  Future<LedgerDocument?> createNew() async => null;

  @override
  Future<String> read(LedgerDocument document) async => files[document.uri]!;

  @override
  Future<void> write(LedgerDocument document, String text) async => files[document.uri] = text;
}
