// The open ledger file shared by the app screens.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_engine.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';

const Duration ledgerOptionSaveDelay = Duration(milliseconds: 500);

class LedgerSession extends ChangeNotifier {
  LedgerSession(this.documents);

  final LedgerDocuments documents;
  final LedgerEngine _engine = LedgerEngine();

  LedgerDocument? document;
  LedgerSnapshot? snapshot;
  String source = '';
  bool busy = false;
  bool settled = false;
  String? error;
  int generation = 0;

  bool _reading = false;
  bool _saving = false;

  bool get loading => _reading || _saving;

  final List<Future<void> Function()> _flushers = <Future<void> Function()>[];
  final List<_PendingEdit> _pending = <_PendingEdit>[];
  Future<void> _chain = Future<void>.value();
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
      _reading = false;
      _publishStatus();
    }
  }

  Future<void> choose(Future<LedgerDocument?> Function() pick) async {
    await flush();
    final int epoch = ++_epoch;
    busy = true;
    error = null;
    _publishStatus();
    try {
      final LedgerDocument? picked = await pick();
      if (_disposed || epoch != _epoch) return;
      await flush();
      if (_disposed || epoch != _epoch) return;
      if (picked == null) {
        busy = false;
        settled = true;
        _publishStatus();
        return;
      }
      await _show(picked, epoch);
    } on PlatformException catch (error) {
      if (_disposed || epoch != _epoch) return;
      busy = false;
      _reading = false;
      settled = true;
      this.error = _message(error);
      _publishStatus();
    }
  }

  Future<void> saveOptions(LedgerOptions options, GuarOptions guar) {
    final LedgerDocument? current = document;
    if (current == null) return Future<void>.value();
    (_editFor(current.uri) ?? _startEdit(current)).options = (options: options, guar: guar);
    return _later(_drain);
  }

  Future<void> savePlugins(List<LedgerPlugin> plugins) {
    final LedgerDocument? current = document;
    if (current == null) return Future<void>.value();
    final _PendingEdit? existing = _editFor(current.uri);
    if ((existing == null || existing.options == null) && _samePlugins(plugins)) return Future<void>.value();
    (existing ?? _startEdit(current)).plugins = plugins;
    return _later(_drain);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_engine.close());
    super.dispose();
  }

  bool _samePlugins(List<LedgerPlugin> plugins) {
    final List<LedgerPlugin>? current = snapshot?.plugins;
    if (current == null || current.length != plugins.length) return false;
    for (int index = 0; index < plugins.length; index++) {
      if (current[index].name != plugins[index].name || current[index].config != plugins[index].config) {
        return false;
      }
    }
    return true;
  }

  Future<void> _later(Future<void> Function() action) {
    final Future<void> result = _chain.then((_) => action());
    _chain = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _show(LedgerDocument? picked, int epoch) async {
    if (_disposed || epoch != _epoch) return;
    if (picked == null) {
      document = null;
      snapshot = null;
      source = '';
      _reading = false;
      busy = false;
      settled = true;
      _publishDocument();
      return;
    }
    if (picked.uri != document?.uri) snapshot = null;
    _reading = true;
    _publishStatus();
    final String text;
    try {
      text = await documents.read(picked);
    } on PlatformException catch (error) {
      if (_disposed || epoch != _epoch) return;
      _reading = false;
      busy = false;
      settled = true;
      this.error = _message(error);
      _publishStatus();
      return;
    }
    if (_disposed || epoch != _epoch) return;
    final LedgerSnapshot prepared = await _engine.prepare(text, picked.displayName);
    if (_disposed || epoch != _epoch) return;
    document = picked;
    source = text;
    snapshot = prepared;
    error = null;
    _reading = false;
    busy = false;
    settled = true;
    _publishDocument();
  }

  _PendingEdit? _editFor(String uri) {
    for (final _PendingEdit edit in _pending) {
      if (edit.document.uri == uri) return edit;
    }
    return null;
  }

  _PendingEdit _startEdit(LedgerDocument current) {
    final _PendingEdit edit = _PendingEdit(current, source);
    _pending.add(edit);
    return edit;
  }

  Future<void> _drain() async {
    if (_pending.isEmpty) {
      await _refresh();
      return;
    }
    _saving = true;
    _publishStatus();
    try {
      while (_pending.isNotEmpty) {
        final _PendingEdit edit = _pending.first;
        final ({LedgerOptions options, GuarOptions guar})? options = edit.options;
        final List<LedgerPlugin>? plugins = edit.plugins;
        edit
          ..options = null
          ..plugins = null;
        if (options != null) {
          final String? next = await _rewriteOptions(edit, options);
          if (edit.options != null) {
            edit.plugins ??= plugins;
            continue;
          }
          if (next != null) await _commit(edit, next);
        }
        if (edit.options != null) {
          edit.plugins ??= plugins;
          continue;
        }
        final List<LedgerPlugin>? latest = edit.plugins ?? plugins;
        edit.plugins = null;
        if (latest != null) {
          final String? next = await _rewritePlugins(edit, latest);
          if (edit.options != null || edit.plugins != null) {
            edit.plugins ??= latest;
            continue;
          }
          if (next != null) await _commit(edit, next);
        }
        if (edit.options == null && edit.plugins == null) _pending.removeAt(0);
      }
      await _refresh();
    } finally {
      _saving = false;
      if (!_disposed) _publishStatus();
    }
  }

  Future<String?> _rewriteOptions(_PendingEdit edit, ({LedgerOptions options, GuarOptions guar}) job) async {
    final String next = await _engine.rewriteOptions(
      edit.source,
      edit.document.displayName,
      job.options,
      job.guar,
      DateTime.now(),
    );
    if (next == edit.source) return null;
    return next;
  }

  Future<String?> _rewritePlugins(_PendingEdit edit, List<LedgerPlugin> plugins) async {
    if (document?.uri == edit.document.uri && snapshot?.source == edit.source && _samePlugins(plugins)) return null;
    final String next = await _engine.rewritePlugins(edit.source, edit.document.displayName, plugins);
    if (next == edit.source) return null;
    return next;
  }

  Future<void> _commit(_PendingEdit edit, String next) async {
    try {
      await documents.write(edit.document, next);
    } on PlatformException catch (error) {
      if (!_disposed && document?.uri == edit.document.uri) this.error = _message(error);
      return;
    }
    edit.source = next;
    if (_disposed || document?.uri != edit.document.uri) return;
    source = next;
    error = null;
  }

  Future<void> _refresh() async {
    final LedgerDocument? current = document;
    if (current == null) return;
    final String text = source;
    if (snapshot?.source == text && snapshot?.filename == current.displayName) return;
    final LedgerSnapshot prepared = await _engine.prepare(text, current.displayName);
    if (document?.uri == current.uri && source == text) snapshot = prepared;
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

class _PendingEdit {
  _PendingEdit(this.document, this.source);

  final LedgerDocument document;
  String source;
  ({LedgerOptions options, GuarOptions guar})? options;
  List<LedgerPlugin>? plugins;
}
