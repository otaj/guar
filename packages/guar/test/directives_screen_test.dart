// Ledger screen: the open ledger's directives, grouped by date in either mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  testWidgets('opens on directives when a ledger is already loaded', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': _ledger},
      ),
    );

    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('taxes.beancount'), findsNothing);
    expect(find.text('Open a ledger'), findsNothing);
    expect(find.widgetWithText(NavigationDestination, 'Plugins'), findsNothing);
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Ledger')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Settings')).dx),
    );
  });

  testWidgets('lists each directive under its date, newest day first', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': _ledger},
      ),
    );

    expect(find.text('Household'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(7));
    _expectTile(tester, 'open Assets:Bank', Icons.lock_open_outlined);
    _expectTile(tester, 'open Expenses:Groceries', Icons.lock_open_outlined);
    _expectTile(tester, 'close Expenses:Groceries', Icons.lock_outlined);
    _expectTile(tester, 'note Assets:Bank', Icons.sticky_note_2_outlined);
    _expectTile(tester, 'price EUR', Icons.sell_outlined);
    _expectTile(tester, 'balance Assets:Bank', Icons.account_balance_outlined);

    // Transactions render as tiles with the payee and the positive amount.
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('12.34 USD'), findsOneWidget);
    expect(find.text('rent due'), findsOneWidget);
    expect(find.text('1.10 USD'), findsOneWidget);
    expect(find.text('-12.34 USD'), findsOneWidget);
    expect(find.textContaining('does not balance'), findsNothing);

    // The date groups run newest first.
    final List<String> days = <String>[
      'Tuesday, January 7, 2020',
      'Monday, January 6, 2020',
      'Sunday, January 5, 2020',
      'Saturday, January 4, 2020',
      'Friday, January 3, 2020',
      'Thursday, January 2, 2020',
      'Wednesday, January 1, 2020',
    ];
    for (int i = 0; i < days.length - 1; i++) {
      expect(_top(tester, days[i]), lessThan(_top(tester, days[i + 1])));
    }
    expect(_top(tester, 'Friday, January 3, 2020'), lessThan(_top(tester, 'Groceries')));
    expect(_top(tester, 'Wednesday, January 1, 2020'), lessThan(_top(tester, 'open Assets:Bank')));
  });

  testWidgets('says when the ledger has no directives', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'empty.beancount'),
        files: const <String, String>{'content://ledger/1': 'option "title" "Empty"\n'},
      ),
    );

    expect(find.text('This ledger has no directives.'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('empty.beancount'), findsNothing);
  });

  testWidgets('keeps a directive that failed a later check', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: const <String, String>{
          'content://ledger/1':
              '2020-01-01 open Assets:Bank USD\n'
              '2020-01-01 open Expenses:Food\n'
              '2020-01-02 * "Shop" "Groceries"\n'
              '  Expenses:Food  12.34 USD\n',
        },
      ),
    );

    expect(find.text('open Assets:Bank'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.textContaining('does not balance'), findsNothing);
    await tester.tap(find.text('1 warning'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not balance'), findsOneWidget);
  });

  testWidgets('starts on directives in advanced mode', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': '$_ledger$_advanced'},
      ),
    );

    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.text('custom guar_option'), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Ledger')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx),
    );
    expect(
      tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Plugins')).dx,
      lessThan(tester.getTopLeft(find.widgetWithText(NavigationDestination, 'Settings')).dx),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('switches to directives after a ledger is opened', (WidgetTester tester) async {
    const LedgerDocument first = LedgerDocument(uri: 'content://ledger/1', displayName: 'first.beancount');
    const LedgerDocument second = LedgerDocument(uri: 'content://ledger/2', displayName: 'second.beancount');
    final _FakeLedgerDocuments documents = _FakeLedgerDocuments(
      currentDocument: first,
      opened: second,
      files: const <String, String>{
        'content://ledger/1':
            'option "title" "First ledger"\n'
            '2020-01-01 open Assets:Bank\n'
            '2020-01-02 * "Alpha" "First"\n'
            '  Assets:Bank  1.00 USD\n'
            '  Assets:Bank -1.00 USD\n',
        'content://ledger/2':
            'option "title" "Second ledger"\n'
            '2020-02-01 open Assets:Bank\n'
            '2020-02-02 * "Beta" "Second"\n'
            '  Assets:Bank  1.00 USD\n'
            '  Assets:Bank -1.00 USD\n',
      },
    );
    await _pumpApp(tester, documents);

    expect(find.text('First ledger'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('first.beancount'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.text('Second ledger'), findsOneWidget);
    expect(find.text('second.beancount'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('First ledger'), findsNothing);
    expect(find.text('First'), findsNothing);
    expect(find.text('Open a ledger'), findsNothing);
  });

  testWidgets('hides a directive type from the ledger screen', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: <String, String>{
          'content://ledger/1': '$_ledger${_hide(<String>['price'])}',
        },
      ),
    );

    expect(find.text('price EUR'), findsNothing);
    expect(find.textContaining('1.10 USD'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('balance Assets:Bank'), findsOneWidget);
    expect(find.text('custom guar_option'), findsOneWidget);
  });

  testWidgets('hides directives generated by a plugin or balance padding', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: const <String, String>{'content://ledger/1': _generatedLedger},
      ),
    );

    expect(find.textContaining('Padding'), findsOneWidget);
    expect(find.text('open Expenses:Food'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('pad Assets:Bank'), findsOneWidget);
    expect(find.text('from Equity:Opening-Balances'), findsOneWidget);

    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: <String, String>{
          'content://ledger/1': '$_generatedLedger${_hide(<String>['generated'])}',
        },
      ),
    );

    expect(find.text('Every directive is hidden.'), findsNothing);
    expect(find.textContaining('Padding'), findsNothing);
    expect(find.text('open Expenses:Food'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('open Assets:Bank'), findsOneWidget);
    expect(find.text('open Equity:Opening-Balances'), findsOneWidget);
    expect(find.text('pad Assets:Bank'), findsOneWidget);
    expect(find.text('from Equity:Opening-Balances'), findsOneWidget);
    expect(find.text('custom fava-option'), findsOneWidget);
    expect(find.text('balance Assets:Bank'), findsOneWidget);
  });

  testWidgets('hiding transactions leaves generated opens on the ledger', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: <String, String>{
          'content://ledger/1': '$_generatedLedger${_hide(<String>['transaction'])}',
        },
      ),
    );

    expect(find.textContaining('Padding'), findsNothing);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('open Expenses:Food'), findsOneWidget);
    expect(find.text('pad Assets:Bank'), findsOneWidget);
  });

  testWidgets('says when every directive is hidden', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: <String, String>{
          'content://ledger/1':
              'option "title" "Household"\n'
              '2020-01-05 price EUR 1.10 USD\n'
              '${_hide(<String>['price', 'custom'])}',
        },
      ),
    );

    expect(find.text('Every directive is hidden.'), findsOneWidget);
    expect(find.text('This ledger has no directives.'), findsNothing);
    expect(find.text('Household'), findsOneWidget);
  });

  testWidgets('ignores a hand-written hide that is not the toggle format', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: const <String, String>{
          'content://ledger/1':
              'option "title" "Household"\n'
              '2020-01-05 price EUR 1.10 USD\n'
              '2020-01-08 custom "guar_option" "hide_price" "true"\n',
        },
      ),
    );

    expect(find.text('price EUR'), findsOneWidget);
    expect(find.textContaining('hide_price: found "true" expected "TRUE"'), findsNothing);
    await tester.tap(find.text('1 warning'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hide_price: found "true" expected "TRUE"'), findsOneWidget);
  });
}

String _hide(List<String> tokens) => <String>[
  for (final String token in tokens) '2020-01-08 custom "guar_option" "hide_$token" "TRUE"\n',
].join();

const String _generatedLedger = '''
option "title" "Household"
plugin "beancount.plugins.auto_accounts"
2019-01-01 custom "fava-option" "insert-entry" "Assets:Bank"

2020-01-01 open Assets:Bank
2020-01-01 open Equity:Opening-Balances
2020-01-02 pad Assets:Bank Equity:Opening-Balances
2020-01-03 balance Assets:Bank 10.00 USD
2020-01-04 * "Shop" "Groceries"
  Expenses:Food  1.00 USD
  Assets:Bank -1.00 USD
''';

const String _advanced = '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n';

const String _ledger = '''
option "title" "Household"

2020-01-01 open Assets:Bank USD
2020-01-02 open Expenses:Groceries
2020-01-03 * "Shop" "Groceries"
  Expenses:Groceries  12.34 USD
  Assets:Bank
2020-01-04 note Assets:Bank "rent due"
2020-01-05 price EUR  1.10 USD
2020-01-06 balance Assets:Bank  -12.34 USD
2020-01-07 close Expenses:Groceries
''';

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void _expectTile(WidgetTester tester, String label, IconData icon) {
  final Finder tile = find.ancestor(of: find.text(label), matching: find.byType(ListTile));
  final Finder typeIcon = find.descendant(of: tile, matching: find.byIcon(icon));
  expect(tile, findsOneWidget);
  expect(typeIcon, findsOneWidget);
  final Rect tileRect = tester.getRect(tile);
  final double screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  expect(tileRect.left, 12);
  expect(tileRect.right, screen - 12);
}

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({this.currentDocument, this.opened, Map<String, String>? files})
    : files = Map<String, String>.of(files ?? const <String, String>{});

  final LedgerDocument? currentDocument;
  final LedgerDocument? opened;
  final Map<String, String> files;

  @override
  Future<LedgerDocument?> current() async => currentDocument;

  @override
  Future<LedgerDocument?> openExisting() async => opened;

  @override
  Future<LedgerDocument?> createNew() async => null;

  @override
  Future<String> read(LedgerDocument document) async => files[document.uri] ?? '';

  @override
  Future<void> write(LedgerDocument document, String text) async {
    files[document.uri] = text;
  }
}
