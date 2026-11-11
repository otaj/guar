// The open-account screen opens from the plus button menu and saves open directives.

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

  testWidgets('the plus button menu offers a transaction and an account', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_open_account');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-transaction-option')), findsOneWidget);
    expect(find.byKey(const Key('add-account-option')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-account-option')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Open account'), findsOneWidget);
  });

  testWidgets('simple mode saves name and date only', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_open_account');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account-option')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currencies')), findsNothing);
    expect(find.byKey(const Key('booking')), findsNothing);
    expect(find.byKey(const Key('add-meta')), findsNothing);

    await tester.enterText(find.byKey(const Key('account')), 'Assets:Bank');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Open account'), findsNothing);
    expect(documents.files[path], '2026-01-01 open Assets:Cash\n$today open Assets:Bank\n');
  });

  testWidgets('advanced mode saves currencies, booking, and metadata', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_open_account');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path:
          '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
          '2026-01-01 open Assets:Cash\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account-option')));
    await tester.pumpAndSettle();
    _tallViewport(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('account')), 'Assets:Bank');
    await tester.enterText(find.byKey(const Key('currencies')), 'USD, EUR');
    await tester.tap(find.byKey(const Key('booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRICT').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-meta')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meta-0-key')), 'note');
    await tester.enterText(find.byKey(const Key('meta-0-value')), 'hello');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Open account'), findsNothing);
    expect(
      documents.files[path],
      '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
      '2026-01-01 open Assets:Cash\n'
      '$today open Assets:Bank USD,EUR "STRICT"\n'
      '  note: "hello"\n',
    );
  });

  testWidgets('keeps save disabled while the account is not valid', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_open_account');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account-option')));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('account')), 'assets:bank');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);
  });

  testWidgets('rejects a duplicate open through the ledger validation', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('guar_open_account');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/ledger.beancount';
    final _FakeDocuments documents = _FakeDocuments(LedgerDocument(uri: path, displayName: path), <String, String>{
      path: '2026-01-01 open Assets:Cash\n',
    });
    await _openSession(tester, documents);

    await tester.tap(find.byKey(const Key('add-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account-option')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('account')), 'Assets:Cash');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duplicate open directive'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);
    expect(documents.files[path], '2026-01-01 open Assets:Cash\n');
  });
}

String _today() {
  final DateTime now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
