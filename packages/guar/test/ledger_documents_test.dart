// Parsing the ledger file returned by the Android document picker.
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/src/ledger_documents.dart';

void main() {
  test('returns null when the picker is cancelled', () {
    expect(ledgerDocumentFromChannel(null), isNull);
  });

  test('reads the uri and display name', () {
    final LedgerDocument? document = ledgerDocumentFromChannel(<Object?, Object?>{
      'uri': 'content://ledger/1',
      'name': 'taxes.beancount',
    });

    expect(document?.uri, 'content://ledger/1');
    expect(document?.displayName, 'taxes.beancount');
  });

  test('rejects a payload that is not a map', () {
    expect(() => ledgerDocumentFromChannel('nope'), throwsFormatException);
  });

  test('rejects a payload without a file name', () {
    expect(
      () => ledgerDocumentFromChannel(<Object?, Object?>{'uri': 'content://ledger/1', 'name': ''}),
      throwsFormatException,
    );
  });
}
