// The open ledger file shared by the app screens.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:guar/src/ledger_documents.dart';

const Duration ledgerOptionSaveDelay = Duration(milliseconds: 500);

class LedgerSession extends ChangeNotifier {
  LedgerSession(this.documents);

  final LedgerDocuments documents;

  LedgerDocument? document;
  String source = '';
  bool busy = false;
  bool settled = false;
  String? error;
  int generation = 0;

  final List<Future<void> Function()> _flushers = <Future<void> Function()>[];
  int _epoch = 0;
  bool _disposed = false;

  VoidCallback bindFlush(Future<void> Function() flush) {
    _flushers.add(flush);
    return () {
      _flushers.remove(flush);
    };
  }

  Future<void> flush() async {
    for (final Future<void> Function() flush in List<Future<void> Function()>.of(_flushers)) {
      await flush();
    }
  }

  Future<void> load() async {
    final int epoch = _epoch;
    try {
      final LedgerDocument? current = await documents.current();
      if (_disposed || epoch != _epoch) return;
      await _show(current, epoch);
    } on PlatformException catch (error) {
      if (_disposed || epoch != _epoch) return;
      this.error = _message(error);
      settled = true;
      _publishStatus();
    }
  }

  Future<void> choose(Future<LedgerDocument?> Function() pick) async {
    final int epoch = ++_epoch;
    busy = true;
    error = null;
    _publishStatus();
    try {
      final LedgerDocument? picked = await pick();
      if (_disposed || epoch != _epoch) return;
      if (picked == null) {
        busy = false;
        settled = true;
        _publishStatus();
        return;
      }
      busy = false;
      _publishStatus();
      await _show(picked, epoch);
    } on PlatformException catch (error) {
      if (_disposed || epoch != _epoch) return;
      busy = false;
      settled = true;
      this.error = _message(error);
      _publishStatus();
    }
  }

  Future<void> write(String text) async {
    final LedgerDocument? current = document;
    if (current == null || text == source) return;
    try {
      await documents.write(current, text);
    } on PlatformException catch (error) {
      this.error = _message(error);
      _publishStatus();
      return;
    }
    source = text;
    error = null;
    _publishStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _show(LedgerDocument? picked, int epoch) async {
    if (picked == null) {
      if (_disposed || epoch != _epoch) return;
      document = null;
      source = '';
      settled = true;
      _publishDocument();
      return;
    }
    final String text;
    try {
      text = await documents.read(picked);
    } on PlatformException catch (error) {
      if (_disposed || epoch != _epoch) return;
      busy = false;
      settled = true;
      this.error = _message(error);
      _publishStatus();
      return;
    }
    if (_disposed || epoch != _epoch) return;
    document = picked;
    source = text;
    busy = false;
    settled = true;
    _publishDocument();
  }

  void _publishStatus() {
    if (!_disposed) notifyListeners();
  }

  void _publishDocument() {
    generation += 1;
    _publishStatus();
  }

  String _message(PlatformException error) {
    final String? message = error.message;
    if (message == null || message.isEmpty) return 'Could not use that file.';
    return message;
  }
}
