// Settings screen: pick a root ledger in the app, then edit its options.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/settings_screen.dart';

void main() {
  testWidgets('opens on settings with the file picker first', (WidgetTester tester) async {
    await _pumpApp(tester, _FakeLedgerDocuments());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Open a ledger'), findsOneWidget);
    expect(find.text('Create a new ledger'), findsOneWidget);
    expect(find.text('No ledger is selected.'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Open a ledger')).dy,
      lessThan(tester.getTopLeft(find.text('Create a new ledger')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Create a new ledger')).dy,
      lessThan(tester.getTopLeft(find.text('No ledger is selected.')).dy),
    );
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('shows a ledger file that was already granted', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'taxes.beancount'), findsOneWidget);
    expect(find.text('Beancount'), findsWidgets);
    expect(tester.widget<TextFormField>(find.byKey(const Key('title'))).controller?.text, 'Beancount');
  });

  testWidgets('choosing a file reloads options without writing the ledger', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      opened: const LedgerDocument(uri: 'content://ledger/2', displayName: 'taxes.beancount'),
      files: const <String, String>{'content://ledger/2': 'option "title" "Taxes"\n'},
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Open a ledger'));
    await tester.pumpAndSettle();

    expect(documents.openCount, 1);
    expect(documents.writeCount, 0);
    expect(find.widgetWithText(FilledButton, 'taxes.beancount'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const Key('title'))).controller?.text, 'Taxes');
  });

  testWidgets('prefills a created ledger title', (WidgetTester tester) async {
    const LedgerDocument created = LedgerDocument(uri: 'content://ledger/3', displayName: 'ledger.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      created: created,
      files: const <String, String>{'content://ledger/3': 'option "title" "Ledger"\n'},
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Create a new ledger'));
    await tester.pumpAndSettle();

    expect(documents.createCount, 1);
    expect(documents.writeCount, 0);
    expect(tester.widget<TextFormField>(find.byKey(const Key('title'))).controller?.text, 'Ledger');
  });

  testWidgets('keeps the current file when the picker is cancelled', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('taxes.beancount'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'taxes.beancount'), findsOneWidget);
    expect(find.textContaining('Could not'), findsNothing);
  });

  testWidgets('explains when access to the file is denied', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        openError: PlatformException(
          code: 'permission_denied',
          message: 'Guar was not allowed to keep access to that file.',
        ),
      ),
    );

    await tester.tap(find.text('Open a ledger'));
    await tester.pumpAndSettle();

    expect(find.text('Guar was not allowed to keep access to that file.'), findsOneWidget);
    expect(find.text('No ledger is selected.'), findsOneWidget);
  });

  testWidgets('disables both actions while a picker is open', (WidgetTester tester) async {
    final Completer<LedgerDocument?> gate = Completer<LedgerDocument?>();
    await _pumpApp(tester, _FakeLedgerDocuments(openGate: gate));

    await tester.tap(find.text('Open a ledger'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Open a ledger')).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create a new ledger')).onPressed, isNull);

    gate.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('keeps a newly chosen file if a saved file arrives later', (WidgetTester tester) async {
    final Completer<LedgerDocument?> lateSaved = Completer<LedgerDocument?>();
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentGate: lateSaved,
      opened: const LedgerDocument(uri: 'content://ledger/2', displayName: 'new.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Open a ledger'));
    await tester.pumpAndSettle();
    lateSaved.complete(const LedgerDocument(uri: 'content://ledger/1', displayName: 'old.beancount'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'new.beancount'), findsOneWidget);
    expect(find.text('old.beancount'), findsNothing);
    expect(documents.openCount, 1);
  });

  testWidgets('writes a booking change immediately and removes the default', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);

    await tester.ensureVisible(find.text('STRICT'));
    await tester.tap(find.text('STRICT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIFO').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], 'option "booking_method" "FIFO"\n');

    await tester.ensureVisible(find.text('FIFO'));
    await tester.tap(find.text('FIFO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRICT').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
  });

  testWidgets('waits to save a title so the field keeps focus', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);

    await tester.tap(find.byKey(const Key('title')));
    await tester.enterText(find.byKey(const Key('title')), 'Household');
    await tester.pump(const Duration(milliseconds: 400));

    expect(documents.writeCount, 0);
    expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(documents.files[document.uri], 'option "title" "Household"\n');
    expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isTrue);
  });

  testWidgets('saves a title when the field loses focus', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);

    await tester.enterText(find.byKey(const Key('title')), 'Household');
    await tester.pump(const Duration(milliseconds: 100));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump();

    expect(documents.writeCount, 1);
    expect(documents.files[document.uri], 'option "title" "Household"\n');
  });

  testWidgets('does not write an invalid currency', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);

    await tester.enterText(find.byKey(const Key('conversion')), 'usd');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(documents.writeCount, 0);
    expect(find.text('not a valid currency code'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({
    this.currentDocument,
    this.opened,
    this.created,
    this.openError,
    this.openGate,
    this.currentGate,
    Map<String, String>? files,
  }) : files = Map<String, String>.of(files ?? const <String, String>{});

  final LedgerDocument? currentDocument;
  final LedgerDocument? opened;
  final LedgerDocument? created;
  final PlatformException? openError;
  final Completer<LedgerDocument?>? openGate;
  final Completer<LedgerDocument?>? currentGate;
  final Map<String, String> files;
  int openCount = 0;
  int createCount = 0;
  int writeCount = 0;

  @override
  Future<LedgerDocument?> current() {
    final Completer<LedgerDocument?>? gate = currentGate;
    if (gate != null) {
      return gate.future;
    }
    return Future<LedgerDocument?>.value(currentDocument);
  }

  @override
  Future<LedgerDocument?> openExisting() async {
    openCount += 1;
    final PlatformException? error = openError;
    if (error != null) {
      throw error;
    }
    final Completer<LedgerDocument?>? gate = openGate;
    if (gate != null) {
      return gate.future;
    }
    return opened;
  }

  @override
  Future<LedgerDocument?> createNew() async {
    createCount += 1;
    return created;
  }

  @override
  Future<String> read(LedgerDocument document) async => files[document.uri] ?? '';

  @override
  Future<void> write(LedgerDocument document, String text) async {
    writeCount += 1;
    files[document.uri] = text;
  }
}
