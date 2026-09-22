// Greeting screen: open or create the root Beancount file.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  testWidgets('greets a new user with open and create', (WidgetTester tester) async {
    await _pumpApp(tester, _FakeLedgerDocuments());

    expect(find.text('Guar'), findsOneWidget);
    expect(find.text('Welcome. Pick a Beancount file to keep your ledger in.'), findsOneWidget);
    expect(find.text('Open a ledger'), findsOneWidget);
    expect(find.text('Android will ask you to allow access to that file.'), findsOneWidget);
    expect(find.text('Create a new ledger'), findsOneWidget);
    expect(find.text('You choose the folder and the file name.'), findsOneWidget);
    expect(find.text('Selected file'), findsNothing);
  });

  testWidgets('shows a ledger file that was already granted', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
      ),
    );

    expect(find.text('taxes.beancount'), findsOneWidget);
  });

  testWidgets('shows the file chosen in the system picker', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      opened: const LedgerDocument(uri: 'content://ledger/2', displayName: 'taxes.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Open a ledger'));
    await tester.pump();

    expect(documents.openCount, 1);
    expect(find.text('taxes.beancount'), findsOneWidget);
    expect(find.text('Selected file'), findsOneWidget);
  });

  testWidgets('shows the file created where the user stored it', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      created: const LedgerDocument(uri: 'content://ledger/3', displayName: 'ledger.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Create a new ledger'));
    await tester.pump();

    expect(documents.createCount, 1);
    expect(find.text('ledger.beancount'), findsOneWidget);
  });

  testWidgets('stays on the greeting when the picker is cancelled', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Open a ledger'));
    await tester.pump();

    expect(find.text('taxes.beancount'), findsOneWidget);
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
    await tester.pump();

    expect(find.text('Guar was not allowed to keep access to that file.'), findsOneWidget);
    expect(find.text('Selected file'), findsNothing);
  });

  testWidgets('disables both actions while a picker is open', (WidgetTester tester) async {
    final Completer<LedgerDocument?> gate = Completer<LedgerDocument?>();
    await _pumpApp(tester, _FakeLedgerDocuments(openGate: gate));

    await tester.tap(find.text('Open a ledger'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Open a ledger')).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create a new ledger')).onPressed, isNull);

    gate.complete(null);
    await tester.pump();
  });

  testWidgets('keeps a newly chosen file if a saved file arrives later', (WidgetTester tester) async {
    final Completer<LedgerDocument?> lateSaved = Completer<LedgerDocument?>();
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentGate: lateSaved,
      opened: const LedgerDocument(uri: 'content://ledger/2', displayName: 'new.beancount'),
    );
    await _pumpApp(tester, documents);

    await tester.tap(find.text('Open a ledger'));
    await tester.pump();
    lateSaved.complete(const LedgerDocument(uri: 'content://ledger/1', displayName: 'old.beancount'));
    await tester.pump();

    expect(find.text('new.beancount'), findsOneWidget);
    expect(find.text('old.beancount'), findsNothing);
    expect(documents.openCount, 1);
  });
}

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pump();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({
    this.currentDocument,
    this.opened,
    this.created,
    this.openError,
    this.openGate,
    this.currentGate,
  });

  final LedgerDocument? currentDocument;
  final LedgerDocument? opened;
  final LedgerDocument? created;
  final PlatformException? openError;
  final Completer<LedgerDocument?>? openGate;
  final Completer<LedgerDocument?>? currentGate;
  int openCount = 0;
  int createCount = 0;

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
}
