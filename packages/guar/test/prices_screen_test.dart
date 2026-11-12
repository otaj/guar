// Price database screen: advanced-only tab, date and pair views with history graphs.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  testWidgets('hides the tab when advanced mode is off', (WidgetTester tester) async {
    await _pumpApp(tester, _files(advanced: false));
    expect(find.widgetWithText(NavigationDestination, 'Prices'), findsNothing);
  });

  testWidgets('lists explicit and inferred prices by date, newest first', (WidgetTester tester) async {
    await _pumpApp(tester, _files(includeInferred: true));
    await _openPrices(tester);

    expect(find.widgetWithText(AppBar, 'Prices'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('price EUR'), findsWidgets);
    expect(find.text('1.10 USD'), findsOneWidget);
    expect(find.text('0.90 USD · inferred'), findsOneWidget);
    // Newest date first.
    expect(_top(tester, 'Monday, January 6, 2020'), lessThan(_top(tester, 'Friday, January 3, 2020')));
  });

  testWidgets('keeps inferred prices off the list unless the option is on', (WidgetTester tester) async {
    await _pumpApp(tester, _files());
    await _openPrices(tester);

    expect(find.text('price EUR'), findsWidgets);
    expect(find.text('0.90 USD · inferred'), findsNothing);
  });

  testWidgets('groups by currency pair with graphs and timeframes', (WidgetTester tester) async {
    await _pumpApp(tester, _files(includeInferred: true));
    await _openPrices(tester);

    expect(find.text('EUR/USD'), findsNothing);
    await tester.tap(find.text('By pair'));
    await tester.pumpAndSettle();

    expect(find.text('EUR/USD'), findsOneWidget);
    expect(find.byType(LineChart), findsWidgets);
    expect(find.text('5 prices'), findsOneWidget);
    expect(find.byKey(const Key('timeframe')), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    // The one-year timeframe starts the graph at the 2023 point.
    expect(find.text('2023-06-01'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('2020-01-03'), findsOneWidget);
  });

  testWidgets('keeps the chosen view while switching tabs', (WidgetTester tester) async {
    await _pumpApp(tester, _files(includeInferred: true));
    await _openPrices(tester);
    await tester.tap(find.text('By pair'));
    await tester.pumpAndSettle();
    expect(find.text('EUR/USD'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('By pair'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Prices'));
    await tester.pumpAndSettle();
    expect(find.text('EUR/USD'), findsOneWidget);
    expect(find.byKey(const Key('timeframe')), findsOneWidget);
  });
}

const String _advanced = '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n';

Map<String, String> _files({bool advanced = true, bool includeInferred = false}) => <String, String>{
  'content://ledger/1':
      'option "title" "Household"\n'
      '${advanced ? _advanced : ''}'
      '2020-01-03 price EUR  1.10 USD\n'
      '2020-01-06 price EUR  1.20 USD\n'
      '2023-06-01 price EUR  1.25 USD\n'
      '2024-02-01 price EUR  1.30 USD\n'
      '2020-01-01 open Assets:Bank\n'
      '2020-01-05 * "Buy" "foreign cash"\n'
      '  Assets:Bank  10.00 USD\n'
      '  Assets:Bank -10.00 EUR @ 0.90 USD\n'
      '${includeInferred ? '2020-01-01 custom "guar_option" "include_inferred_prices" "TRUE"\n' : ''}',
};

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

Future<void> _openPrices(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NavigationDestination, 'Prices'));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester, Map<String, String> files) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MainApp(
      documents: _FakeLedgerDocuments(
        currentDocument: const LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount'),
        files: files,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({required this.currentDocument, Map<String, String>? files})
    : files = Map<String, String>.of(files ?? const <String, String>{});

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
