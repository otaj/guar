// MainApp: the language guar_option picks the locale, English is the fallback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/main.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  group('ledgerLocale', () {
    test('null and empty follow the phone', () {
      expect(ledgerLocale(null), isNull);
      expect(ledgerLocale(''), isNull);
    });

    test('a supported language is used as-is', () {
      expect(ledgerLocale('en'), const Locale('en'));
    });

    test('an unknown language falls back to English', () {
      expect(ledgerLocale('xx'), GuarLocalizations.supportedLocales.first);
    });
  });

  testWidgets('follows the phone language unless the guar option overrides it', (WidgetTester tester) async {
    const LedgerDocument document = LedgerDocument(uri: 'content://ledger/1', displayName: 'taxes.beancount');
    await _pumpApp(tester, _FakeLedgerDocuments(currentDocument: document));
    MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull);
    expect(Localizations.localeOf(tester.element(find.byType(Scaffold).first)), const Locale('en'));

    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{
          'content://ledger/1': '2020-01-01 custom "guar_option" "language" "en"\n',
        },
      ),
    );
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));

    await _pumpApp(
      tester,
      _FakeLedgerDocuments(
        currentDocument: document,
        files: const <String, String>{
          'content://ledger/1': '2020-01-01 custom "guar_option" "language" "xx"\n',
        },
      ),
    );
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(find.widgetWithText(NavigationDestination, 'Ledger'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, LedgerDocuments documents) async {
  await tester.pumpWidget(MainApp(documents: documents));
  await tester.pumpAndSettle();
}

class _FakeLedgerDocuments implements LedgerDocuments {
  _FakeLedgerDocuments({this.currentDocument, Map<String, String>? files})
    : files = Map<String, String>.of(files ?? const <String, String>{});

  final LedgerDocument? currentDocument;
  final Map<String, String> files;

  @override
  Future<LedgerDocument?> current() => Future<LedgerDocument?>.value(currentDocument);

  @override
  Future<LedgerDocument?> openExisting() async => currentDocument;

  @override
  Future<LedgerDocument?> createNew() async => null;

  @override
  Future<String> read(LedgerDocument document) => Future<String>.value(files[document.uri] ?? '');

  @override
  Future<void> write(LedgerDocument document, String text) async {
    files[document.uri] = text;
  }
}
