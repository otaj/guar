// Settings screen: pick a root ledger in the app, then edit its options.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_engine.dart';
import 'package:guar/src/ledger_session.dart';

void main() {
  testWidgets('opens on settings with the file picker first', (WidgetTester tester) async {
    await _pumpApp(tester, _FakeLedgerDocuments());

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
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
    expect(find.text('Advanced UI'), findsNothing);
  });

  testWidgets('shows a ledger file that was already granted', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
      ),
    );
    await _showSettings(tester);

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
    await _showSettings(tester);

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
    await _showSettings(tester);

    expect(documents.createCount, 1);
    expect(documents.writeCount, 0);
    expect(tester.widget<TextFormField>(find.byKey(const Key('title'))).controller?.text, 'Ledger');
  });

  testWidgets('keeps the current file when the picker is cancelled', (WidgetTester tester) async {
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

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
    await _showSettings(tester);

    expect(find.widgetWithText(FilledButton, 'new.beancount'), findsOneWidget);
    expect(find.text('old.beancount'), findsNothing);
    expect(documents.openCount, 1);
  });

  testWidgets('shows a spinner while a ledger file is read', (WidgetTester tester) async {
    final Completer<String> gate = Completer<String>();
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
      readGate: gate,
    );
    await tester.pumpWidget(MainApp(documents: documents));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Open a ledger'), findsNothing);
    expect(documents.readCount, 1);

    gate.complete('option "title" "Taxes"\n');
    await tester.pumpAndSettle();

    expect(find.text('Taxes'), findsOneWidget);
    expect(documents.readCount, 1);
  });

  testWidgets('writes a booking change immediately and removes the default', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);
    final int parses = debugLedgerParses;

    await tester.ensureVisible(find.text('STRICT'));
    await tester.tap(find.text('STRICT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIFO').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], 'option "booking_method" "FIFO"\n');
    expect(documents.readCount, 1);
    expect(debugLedgerParses, parses + 1);

    await tester.ensureVisible(find.text('FIFO'));
    await tester.tap(find.text('FIFO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRICT').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
    expect(documents.readCount, 1);
    expect(debugLedgerParses, parses + 2);
  });

  testWidgets('prepares a ledger off the ui isolate', (WidgetTester tester) async {
    debugForceLedgerIsolate = true;
    addTearDown(() => debugForceLedgerIsolate = false);
    final LedgerEngine engine = LedgerEngine();
    addTearDown(engine.close);
    final LedgerSnapshot? snapshot = await tester.runAsync(
      () => engine.prepare('option "title" "Taxes"\n', 'taxes.beancount'),
    );
    expect(snapshot?.options.options.title, 'Taxes');
  });

  testWidgets('waits to save a title so the field keeps focus', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    await tester.ensureVisible(find.byKey(const Key('title')));
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

  testWidgets('finishes saving the previous file when another file is opened', (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    debugLedgerRewriteGate = gate;
    addTearDown(() {
      debugLedgerRewriteGate = null;
      if (!gate.isCompleted) gate.complete();
    });
    const LedgerDocument previous = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    const LedgerDocument opened = LedgerDocument(uri: 'content://ledger/2', displayName: 'new.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: previous,
      opened: opened,
      files: const <String, String>{'content://ledger/2': 'option "title" "New"\n'},
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    await tester.enterText(find.byKey(const Key('title')), 'Household');
    await tester.pump(const Duration(milliseconds: 100));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(documents.writeCount, 0);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'taxes.beancount'));
    await tester.tap(find.widgetWithText(FilledButton, 'taxes.beancount'));
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(documents.writeCount, 0);
    expect(documents.files[opened.uri], 'option "title" "New"\n');

    gate.complete();
    await tester.pumpAndSettle();

    expect(documents.writeCount, 1);
    expect(documents.files[previous.uri], 'option "title" "Household"\n');
    expect(documents.files[opened.uri], 'option "title" "New"\n');
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Household'), findsNothing);
  });

  testWidgets('saves a title when the field loses focus', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

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
    await _showSettings(tester);

    await tester.enterText(find.byKey(const Key('conversion')), 'usd');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(documents.writeCount, 0);
    expect(find.text('not a valid currency code'), findsOneWidget);
  });

  testWidgets('writes advanced_ui when the switch is turned on', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('advancedUi'))).value, isFalse);

    await tester.ensureVisible(find.byKey(const Key('advancedUi')));
    await tester.tap(find.byKey(const Key('advancedUi')));
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final String today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(documents.files[document.uri], '$today custom "guar_option" "advanced_ui" "TRUE"\n');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Ledger')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx),
    );
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Settings')).dx),
    );
  });

  testWidgets('turns advanced UI off by removing the guar option', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{
        'content://ledger/1': '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n',
      },
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('advancedUi'))).value, isTrue);
    expect(documents.writeCount, 0);

    await tester.ensureVisible(find.byKey(const Key('advancedUi')));
    await tester.tap(find.byKey(const Key('advancedUi')));
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('advancedUi'))).value, isFalse);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Ledger'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Plugins'), findsNothing);
  });

  testWidgets('writes allow_unopened_accounts when the switch is turned on', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('allowUnopenedAccounts'))).value, isFalse);

    await tester.ensureVisible(find.byKey(const Key('allowUnopenedAccounts')));
    await tester.tap(find.byKey(const Key('allowUnopenedAccounts')));
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final String today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(documents.files[document.uri], '$today custom "guar_option" "allow_unopened_accounts" "TRUE"\n');

    await tester.ensureVisible(find.byKey(const Key('allowUnopenedAccounts')));
    await tester.tap(find.byKey(const Key('allowUnopenedAccounts')));
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('allowUnopenedAccounts'))).value, isFalse);
  });

  testWidgets('writes default option lines when the switch is turned on', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('writeDefaultOptions'))).value, isFalse);

    await tester.ensureVisible(find.byKey(const Key('writeDefaultOptions')));
    await tester.tap(find.byKey(const Key('writeDefaultOptions')));
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final String today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final String? written = documents.files[document.uri];
    expect(written, contains('option "title" "Beancount"'));
    expect(written, contains('option "booking_method" "STRICT"'));
    expect(written, contains('$today custom "guar_option" "write_default_options" "TRUE"'));
    expect(written, isNot(contains('advanced_ui')));
  });

  testWidgets('turns write default options off by removing defaults and the guar option', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{
        'content://ledger/1':
            'option "title" "Beancount"\n'
            '2020-01-01 custom "guar_option" "write_default_options" "TRUE"\n',
      },
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('writeDefaultOptions'))).value, isTrue);
    expect(documents.writeCount, 0);

    await tester.ensureVisible(find.byKey(const Key('writeDefaultOptions')));
    await tester.tap(find.byKey(const Key('writeDefaultOptions')));
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('writeDefaultOptions'))).value, isFalse);
  });

  testWidgets('writes hide_directives and the ledger screen drops that type', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{
        'content://ledger/1':
            'option "title" "Household"\n'
            '2020-01-01 open Assets:Bank\n'
            '2020-01-05 price EUR 1.10 USD\n',
      },
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('hide-price'))).value, isFalse);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('hide-generated'))).value, isFalse);

    await tester.ensureVisible(find.byKey(const Key('hide-generated')));
    await tester.tap(find.byKey(const Key('hide-generated')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hide-price')));
    await tester.tap(find.byKey(const Key('hide-price')));
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final String today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(
      documents.files[document.uri],
      'option "title" "Household"\n'
      '$today custom "guar_option" "hide_generated" "TRUE"\n'
      '$today custom "guar_option" "hide_price" "TRUE"\n'
      '2020-01-01 open Assets:Bank\n'
      '2020-01-05 price EUR 1.10 USD\n',
    );
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('hide-price'))).value, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('hide-generated'))).value, isTrue);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Ledger'));
    await tester.pumpAndSettle();

    expect(find.text('price EUR'), findsNothing);
    expect(find.text('open Assets:Bank'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
  });

  testWidgets('groups settings and keeps advanced options hidden', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(tester, _FakeLedgerDocuments(currentDocument: document));
    await _showSettings(tester);

    expect(find.text('Account names'), findsOneWidget);
    expect(find.text('Advanced settings'), findsOneWidget);
    expect(find.text('Insert Python path'), findsNothing);
    expect(find.textContaining('No effect in Guar'), findsNothing);
    expect(tester.getTopLeft(find.text('Account names')).dy, greaterThan(tester.getTopLeft(find.text('Title')).dy));

    await tester.ensureVisible(find.byKey(const Key('help-title')));
    await tester.tap(find.byKey(const Key('help-title')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Guar shows it on the ledger screen'), findsOneWidget);
  });

  testWidgets('leaves a hidden option line unchanged when another setting is saved', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    const String python = 'option "insert_pythonpath" "TRUE" ; keep';
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{'content://ledger/1': '$python\n'},
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    await tester.enterText(find.byKey(const Key('title')), 'Household');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(
      documents.files[document.uri],
      'option "title" "Household"\n'
      '$python\n',
    );
  });

  testWidgets('shows an unused warning and allows the edit once advanced settings are on', (
    WidgetTester tester,
  ) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{'content://ledger/1': 'option "insert_pythonpath" "TRUE"\n'},
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    await tester.ensureVisible(find.byKey(const Key('showAdvanced')));
    await tester.tap(find.byKey(const Key('showAdvanced')));
    await tester.pumpAndSettle();

    expect(find.text('Insert Python path'), findsOneWidget);
    expect(find.text('No effect in Guar. Python plugins are not run.'), findsOneWidget);
    expect(find.text('Compatibility'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('pythonpath')));
    await tester.tap(find.byKey(const Key('pythonpath')));
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
  });

  testWidgets('writes a language option and removes it for the system default', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(currentDocument: document);
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('language'))).initialValue, '');

    await tester.ensureVisible(find.byKey(const Key('language')));
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final String today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(documents.files[document.uri], '$today custom "guar_option" "language" "en"\n');

    await tester.ensureVisible(find.byKey(const Key('language')));
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System default').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('language'))).initialValue, '');
  });

  testWidgets('keeps a handwritten language and lets the system default remove it', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: document,
      files: const <String, String>{
        'content://ledger/1': '2020-01-01 custom "guar_option" "language" "xx"\n',
      },
    );
    await _pumpApp(tester, documents);
    await _showSettings(tester);

    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('language'))).initialValue, 'xx');
    expect(find.text('xx'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('language')));
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System default').last);
    await tester.pumpAndSettle();

    expect(documents.files[document.uri], '');
  });
}

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

Future<void> _showSettings(WidgetTester tester) async {
  final Finder settings = find.widgetWithText(NavigationDestination, 'Settings');
  if (settings.evaluate().isEmpty) return;
  await tester.tap(settings);
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
    this.readGate,
    Map<String, String>? files,
  }) : files = Map<String, String>.of(files ?? const <String, String>{});

  final LedgerDocument? currentDocument;
  final LedgerDocument? opened;
  final LedgerDocument? created;
  final PlatformException? openError;
  final Completer<LedgerDocument?>? openGate;
  final Completer<LedgerDocument?>? currentGate;
  final Completer<String>? readGate;
  final Map<String, String> files;
  int openCount = 0;
  int createCount = 0;
  int writeCount = 0;
  int readCount = 0;

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
  Future<String> read(LedgerDocument document) {
    readCount += 1;
    final Completer<String>? gate = readGate;
    if (gate != null) return gate.future;
    return Future<String>.value(files[document.uri] ?? '');
  }

  @override
  Future<void> write(LedgerDocument document, String text) async {
    writeCount += 1;
    files[document.uri] = text;
  }
}
