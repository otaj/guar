// Balances screen: accounts grouped by type in a collapsible tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  testWidgets('shows balances grouped by type, collapsed to the roots', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'ledger.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': _ledger},
      ),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Balances'));
    await tester.pumpAndSettle();

    // Root-type groups run in bcf's order.
    expect(_top(tester, 'Assets'), lessThan(_top(tester, 'Expenses')));
    expect(_top(tester, 'Expenses'), lessThan(_top(tester, 'Income')));
    expect(_top(tester, 'Income'), lessThan(_top(tester, 'Liabilities')));
    expect(_top(tester, 'Liabilities'), lessThan(_top(tester, 'Equity')));

    // Roots are visible with their own balances; children stay hidden.
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Broker'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Opening-Balances'), findsOneWidget);
    expect(find.text('Savings'), findsNothing);
    expect(find.text('Cash'), findsNothing);

    // Real nodes show their own balance, largest currency first.
    expect(find.text('10.00 USD'), findsNWidgets(2)); // Bank and the virtual Broker aggregate
    expect(find.text('3.00 EUR'), findsOneWidget);
    expect(find.text('5.00 USD'), findsOneWidget);
    expect(find.text('-20.00 USD'), findsOneWidget);
    expect(find.text('-3.00 EUR'), findsOneWidget);
    expect(find.text('-5.00 USD'), findsOneWidget);

    // Unused and closed accounts get their placeholders.
    expect(find.text('No activity'), findsOneWidget);
    expect(find.text('Closed Jan 2'), findsOneWidget);
  });

  testWidgets('expands an account path to reveal its children', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'ledger.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{'content://ledger/1': _ledger},
      ),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Balances'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Broker'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('10.00 USD'), findsNWidgets(3)); // Bank, virtual Broker, real Cash

    await tester.tap(find.text('Broker'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsNothing);
    expect(find.text('10.00 USD'), findsNWidgets(2));
  });

  testWidgets('hides an account with a subaccount-only tree', (WidgetTester tester) async {
    // Assets:Bank:Savings is declared but Bank itself is only created by postings,
    // so it still appears as a real node once opened by the postings' accounts.
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'ledger.beancount');
    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{
          'content://ledger/1':
              'option "title" "Household"\n'
              '2020-01-01 open Assets:Bank:Savings\n'
              '2020-01-02 * "Seed"\n'
              '  Income:Work  -5.00 USD\n'
              '  Assets:Bank:Savings  5.00 USD\n',
        },
      ),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Balances'));
    await tester.pumpAndSettle();

    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Savings'), findsNothing);
    expect(find.text('5.00 USD'), findsOneWidget);

    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('5.00 USD'), findsNWidgets(2)); // virtual Bank aggregate and real Savings
  });
}

const String _ledger = '''
option "title" "Household"

2020-01-01 open Assets:Bank USD
2020-01-01 open Assets:Bank:Savings
2020-01-01 open Assets:Broker:Cash
2020-01-01 open Assets:Old
2020-01-02 close Assets:Old
2020-01-01 open Expenses:Food
2020-01-01 open Income:Work
2020-01-01 open Liabilities:Card USD,EUR
2020-01-01 open Equity:Opening-Balances
2020-01-05 * "Pay"
  Income:Work  -20.00 USD
  Assets:Bank  20.00 USD
2020-01-06 * "Transfer"
  Assets:Bank  -10.00 USD
  Assets:Broker:Cash  10.00 USD
2020-01-07 * "Shop"
  Expenses:Food  5.00 USD
  Liabilities:Card  -5.00 USD
2020-01-08 * "Euro"
  Income:Work  -3.00 EUR
  Assets:Bank  3.00 EUR
''';

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({required this.currentDocument, required Map<String, String> files})
    : files = Map<String, String>.of(files);

  final LedgerDocument currentDocument;
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
