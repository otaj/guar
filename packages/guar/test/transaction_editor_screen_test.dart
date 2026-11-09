// The transaction editor opens from the FAB and saves balanced transactions.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

class _FakeDocuments implements LedgerDocuments {
  _FakeDocuments(this.currentDocument, Map<String, String> files) : files = Map<String, String>.of(files);

  final LedgerDocument? currentDocument;
  final Map<String, String> files;

  @override
  Future<LedgerDocument?> current() async => currentDocument;

  @override
  Future<LedgerDocument?> openExisting() async => null;

  @override
  Future<LedgerDocument?> createNew() async => null;

  @override
  Future<String> read(LedgerDocument document) async => files[document.uri]!;

  @override
  Future<void> write(LedgerDocument document, String text) async => files[document.uri] = text;
}

Future<void> _openSession(WidgetTester tester, _FakeDocuments documents) async {
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

void main() {
  final String today = _today();

  testWidgets('the FAB appears only while a ledger is loaded', (WidgetTester tester) async {
    final _FakeDocuments empty = _FakeDocuments(null, <String, String>{});
    await tester.pumpWidget(MainApp(documents: empty));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-transaction')), findsNothing);

    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n2026-01-01 open Expenses:Food\n',
    });
    await tester.pumpWidget(MainApp(documents: documents));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-transaction')), findsOneWidget);
  });

  testWidgets('simple mode saves a balanced two-leg transaction', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n2026-01-01 open Expenses:Food\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    expect(find.byKey(const Key('add-leg')), findsNothing);

    await tester.enterText(find.byKey(const Key('leg-0-number')), '12.30');
    await tester.enterText(find.byKey(const Key('leg-0-currency')), 'USD');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsNothing);
    expect(
      documents.files[path],
      '2026-01-01 open Assets:Cash\n2026-01-01 open Expenses:Food\n'
      '$today * ""\n  Assets:Cash  -12.3 USD\n  Expenses:Food  12.3 USD\n',
    );
  });

  testWidgets('simple mode keeps save disabled without an amount', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n2026-01-01 open Expenses:Food\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);
  });

  testWidgets('advanced mode saves an elided leg and shows the extras', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path:
          '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
          '2026-01-01 open Assets:Cash\n'
          '2026-01-01 open Expenses:Food\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    _tallViewport(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-leg')), findsOneWidget);
    expect(find.byKey(const Key('tags')), findsOneWidget);
    expect(find.byKey(const Key('links')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('leg-0-number')), '12.30');
    await tester.enterText(find.byKey(const Key('leg-0-currency')), 'USD');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsNothing);
    expect(
      documents.files[path],
      contains('$today * ""\n  Assets:Cash  12.3 USD\n  Expenses:Food\n'),
    );
  });

  testWidgets('advanced mode keeps save disabled while no leg can be interpolated', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path:
          '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
          '2026-01-01 open Assets:Cash\n'
          '2026-01-01 open Expenses:Food\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    _tallViewport(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);
  });

  testWidgets('account dropdowns hide accounts opened later or closed', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path:
          '2026-01-01 open Assets:Cash\n'
          '2026-01-01 open Expenses:Food\n'
          '2026-06-01 close Expenses:Food\n'
          '2027-06-01 open Assets:Later\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leg-0-account')));
    await tester.pumpAndSettle();
    expect(find.text('Assets:Cash').last, findsOneWidget);
    expect(find.text('Assets:Later'), findsNothing);
    expect(find.text('Expenses:Food'), findsNothing);
  });
}

String _today() {
  final DateTime now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
