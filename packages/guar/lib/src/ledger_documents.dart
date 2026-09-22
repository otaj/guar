// The ledger file the user granted Guar access to.
import 'package:flutter/services.dart';

const String _channelName = 'dev.otaj.guar/ledger_documents';
const MethodChannel _channel = MethodChannel(_channelName);

class LedgerDocument {
  const LedgerDocument({required this.uri, required this.displayName});

  final String uri;
  final String displayName;
}

abstract interface class LedgerDocuments {
  Future<LedgerDocument?> current();

  Future<LedgerDocument?> openExisting();

  Future<LedgerDocument?> createNew();
}

class PlatformLedgerDocuments implements LedgerDocuments {
  const PlatformLedgerDocuments();

  @override
  Future<LedgerDocument?> current() => _invoke('current');

  @override
  Future<LedgerDocument?> openExisting() => _invoke('open');

  @override
  Future<LedgerDocument?> createNew() => _invoke('create');

  Future<LedgerDocument?> _invoke(String method) async =>
      ledgerDocumentFromChannel(await _channel.invokeMethod<Object?>(method));
}

LedgerDocument? ledgerDocumentFromChannel(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Unexpected ledger document payload');
  }
  final Object? uri = value['uri'];
  final Object? name = value['name'];
  if (uri is! String || uri.isEmpty || name is! String || name.isEmpty) {
    throw const FormatException('Unexpected ledger document payload');
  }
  return LedgerDocument(uri: uri, displayName: name);
}
