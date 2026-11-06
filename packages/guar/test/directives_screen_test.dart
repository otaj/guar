// Ledger screen: the open ledger's directives, first in either mode.

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

  testWidgets('lists each directive and leaves postings off the row', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': _ledger},
      ),
    );

    expect(find.text('Household'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(7));
    expect(find.byType(ListTile), findsNothing);
    _expectChip(tester, '2020-01-01 · Open', Icons.lock_open_outlined);
    _expectChip(tester, '2020-01-02 · Open', Icons.lock_open_outlined);
    _expectChip(tester, '2020-01-03 · Transaction', Icons.receipt_long_outlined);
    _expectChip(tester, '2020-01-04 · Note', Icons.sticky_note_2_outlined);
    _expectChip(tester, '2020-01-05 · Price', Icons.sell_outlined);
    _expectChip(tester, '2020-01-06 · Balance', Icons.account_balance_outlined);
    _expectChip(tester, '2020-01-07 · Close', Icons.lock_outlined);
    expect(find.text('Assets:Bank'), findsOneWidget);
    expect(find.text('Expenses:Groceries'), findsNWidgets(2));
    expect(find.text('* Shop — Groceries'), findsOneWidget);
    expect(find.textContaining('12.34'), findsOneWidget);
    expect(find.text('Assets:Bank rent due'), findsOneWidget);
    expect(find.textContaining('EUR'), findsOneWidget);
    expect(find.textContaining('does not balance'), findsNothing);

    expect(_top(tester, '2020-01-01 · Open'), lessThan(_top(tester, '2020-01-02 · Open')));
    expect(_top(tester, '2020-01-02 · Open'), lessThan(_top(tester, '2020-01-03 · Transaction')));
    expect(_top(tester, '2020-01-03 · Transaction'), lessThan(_top(tester, '2020-01-04 · Note')));
    expect(_top(tester, '2020-01-04 · Note'), lessThan(_top(tester, '2020-01-05 · Price')));
    expect(_top(tester, '2020-01-05 · Price'), lessThan(_top(tester, '2020-01-06 · Balance')));
    expect(_top(tester, '2020-01-06 · Balance'), lessThan(_top(tester, '2020-01-07 · Close')));
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

    expect(find.text('Assets:Bank'), findsOneWidget);
    expect(find.text('* Shop — Groceries'), findsOneWidget);
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
    expect(find.text('guar_option'), findsOneWidget);
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
    expect(find.text('* Shop — Groceries'), findsNothing);
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
    expect(find.text('* Alpha — First'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('first.beancount'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Ledger'), findsOneWidget);
    expect(find.text('Second ledger'), findsOneWidget);
    expect(find.text('second.beancount'), findsNothing);
    expect(find.text('* Beta — Second'), findsOneWidget);
    expect(find.text('First ledger'), findsNothing);
    expect(find.text('* Alpha — First'), findsNothing);
    expect(find.text('Open a ledger'), findsNothing);
  });
}

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

void _expectChip(WidgetTester tester, String subtitle, IconData icon) {
  final Finder chip = find.ancestor(of: find.text(subtitle), matching: find.byType(Chip));
  final Finder typeIcon = find.descendant(of: chip, matching: find.byIcon(icon));
  expect(chip, findsOneWidget);
  expect(typeIcon, findsOneWidget);
  final Rect chipRect = tester.getRect(chip);
  final double screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  expect(chipRect.left, 28);
  expect(chipRect.right, screen - 28);
  expect(tester.getTopLeft(typeIcon).dx, lessThan(chipRect.center.dx));
  expect(tester.getTopLeft(typeIcon).dx, lessThan(tester.getTopLeft(find.text(subtitle)).dx));
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
