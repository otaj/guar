// Plugins screen: toggle, describe, configure, and reorder plugins in the ledger.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_plugins/guar_plugins.dart';

void main() {
  testWidgets('shows plugins only when advanced UI is on', (WidgetTester tester) async {
    await _pumpApp(tester, _FakeLedgerDocuments());

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(tester, _FakeLedgerDocuments(currentDocument: document));
    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Plugins'), findsNothing);

    await _pumpApp(tester, _ledger(document));
    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Ledger')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx),
    );
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Settings')).dx),
    );
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Plugins'), findsOneWidget);
    expect(find.text('taxes.beancount'), findsOneWidget);
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('shows the catalog description and writes a plugin in order', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _ledger(document);
    final PluginDeclaration autoAccounts = pluginCatalog.firstWhere(
      (PluginDeclaration plugin) => plugin.name == 'beancount.plugins.auto_accounts',
    );
    await _pumpApp(tester, documents);
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    expect(find.text('taxes.beancount'), findsOneWidget);
    expect(find.text('None of the plugins are turned on.'), findsOneWidget);
    expect(find.text(autoAccounts.description), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('about-beancount.plugins.auto_accounts')));
    await tester.tap(find.byKey(const Key('about-beancount.plugins.auto_accounts')));
    await tester.pumpAndSettle();

    expect(find.text(autoAccounts.description), findsOneWidget);

    await tester.tap(find.byKey(const Key('about-beancount.plugins.auto_accounts')));
    await tester.pumpAndSettle();
    expect(find.text(autoAccounts.description), findsNothing);

    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.auto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.auto_accounts')));
    await tester.pumpAndSettle();

    expect(
      documents.files[document.uri],
      'plugin "beancount.plugins.auto"\n'
      'plugin "beancount.plugins.auto_accounts"\n'
      '$_advanced',
    );

    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.auto')));
    await tester.pumpAndSettle();
    expect(documents.files[document.uri], 'plugin "beancount.plugins.auto_accounts"\n$_advanced');
  });

  testWidgets('writes a plugin configuration and can drag plugins into a new order', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _ledger(document);
    await _pumpApp(tester, documents);
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.currency_accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about-beancount.plugins.currency_accounts')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('config-beancount.plugins.currency_accounts-base')), 'Equity:Trading');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(
      documents.files[document.uri],
      'plugin "beancount.plugins.currency_accounts" "Equity:Trading"\n'
      '$_advanced',
    );

    await tester.ensureVisible(find.byKey(const Key('toggle-beancount.plugins.auto')));
    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.auto')));
    await tester.pumpAndSettle();
    expect(
      documents.files[document.uri],
      'plugin "beancount.plugins.currency_accounts" "Equity:Trading"\n'
      'plugin "beancount.plugins.auto"\n'
      '$_advanced',
    );

    await tester.tap(find.byKey(const Key('about-beancount.plugins.currency_accounts')));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byKey(const Key('drag-beancount.plugins.currency_accounts')),
      const Offset(0, 240),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(
      documents.files[document.uri],
      'plugin "beancount.plugins.auto"\n'
      'plugin "beancount.plugins.currency_accounts" "Equity:Trading"\n'
      '$_advanced',
    );
  });

  testWidgets('writes a decimal tolerance and rejects text that is not one', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _ledger(document);
    await _pumpApp(tester, documents);
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.check_average_cost')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about-beancount.plugins.check_average_cost')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('config-beancount.plugins.check_average_cost-tolerance')),
      'nope',
    );
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(find.text('Enter a decimal'), findsOneWidget);
    expect(documents.files[document.uri], 'plugin "beancount.plugins.check_average_cost"\n$_advanced');

    await tester.enterText(find.byKey(const Key('config-beancount.plugins.check_average_cost-tolerance')), '1');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(
      documents.files[document.uri],
      'plugin "beancount.plugins.check_average_cost" "1.0"\n'
      '$_advanced',
    );
  });

  testWidgets('writes a whole number of days and rejects a fraction', (WidgetTester tester) async {
    const String name = 'beancount_reds_plugins.zerosum.zerosum';
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _ledger(document);
    await _pumpApp(tester, documents);
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle-$name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about-$name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-$name-accounts')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('config-$name-accounts-0-0')), 'Assets:Zero');
    await tester.enterText(find.byKey(const Key('config-$name-accounts-0-2')), '1.5');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(documents.files[document.uri], 'plugin "$name"\n$_advanced');

    await tester.enterText(find.byKey(const Key('config-$name-accounts-0-2')), '90');
    await tester.pump(ledgerOptionSaveDelay);
    await tester.pump();

    expect(documents.files[document.uri], contains("{'Assets:Zero': ['', 90]}"));
  });

  testWidgets('keeps an unknown plugin and does not drop options', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    final _FakeLedgerDocuments documents = _ledger(document, before: 'plugin "custom.mine" "keep"\n');
    await _pumpApp(tester, documents);
    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    expect(find.text('custom.mine'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('toggle-beancount.plugins.leafonly')));
    await tester.tap(find.byKey(const Key('toggle-beancount.plugins.leafonly')));
    await tester.pumpAndSettle();

    expect(
      documents.files[document.uri],
      'plugin "custom.mine" "keep"\n'
      'plugin "beancount.plugins.leafonly"\n'
      '$_advanced',
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('STRICT'));
    await tester.tap(find.text('STRICT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIFO').last);
    await tester.pumpAndSettle();

    final String? written = documents.files[document.uri];
    expect(written, contains('option "booking_method" "FIFO"'));
    expect(written, contains('plugin "custom.mine" "keep"'));
    expect(written, contains('plugin "beancount.plugins.leafonly"'));
  });
}

const String _advanced = '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n';

_FakeLedgerDocuments _ledger(LedgerDocument document, {String before = ''}) => _FakeLedgerDocuments(
  currentDocument: document,
  files: <String, String>{document.uri: '$before$_advanced'},
);

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({this.currentDocument, Map<String, String>? files})
    : files = Map<String, String>.of(files ?? const <String, String>{});

  final LedgerDocument? currentDocument;
  final Map<String, String> files;

  @override
  Future<LedgerDocument?> current() async => currentDocument;

  @override
  Future<LedgerDocument?> openExisting() async => null;

  @override
  Future<LedgerDocument?> createNew() async => null;

  @override
  Future<String> read(LedgerDocument document) async => files[document.uri] ?? '';

  @override
  Future<void> write(LedgerDocument document, String text) async {
    files[document.uri] = text;
  }
}
