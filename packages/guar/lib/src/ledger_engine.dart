// Parses a ledger once, off the UI isolate, and reuses that parse for a later rewrite.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:guar/src/book_ledger.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as parser;

bool debugForceLedgerIsolate = false;

int debugLedgerParses = 0;

// Holds a rewrite so a test can open another file before that save lands.
Completer<void>? debugLedgerRewriteGate;

sealed class AppendOutcome {
  const AppendOutcome();
}

class AppendOk extends AppendOutcome {
  const AppendOk(this.text);

  final String text;
}

class AppendFailed extends AppendOutcome {
  const AppendFailed(this.errors);

  final List<String> errors;
}

typedef _IncludeRead = ({Map<String, String> read, parser.ParsedLedger parsed});

class LedgerEngine {
  LedgerEngine() {
    if (debugForceLedgerIsolate || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _remote = _RemoteMemory();
    } else {
      // Microtasks, so a widget test's pump() finishes the work before the next frame.
      _memory = _Memory();
    }
  }

  _Memory? _memory;
  _RemoteMemory? _remote;

  Future<LedgerSnapshot> prepare(String source, String filename) {
    final _Memory? memory = _memory;
    if (memory != null) return Future<LedgerSnapshot>.microtask(() => memory.prepare(source, filename));
    return _remote!.prepare(source, filename);
  }

  Future<String> rewriteOptions(
    String source,
    String filename,
    LedgerOptions options,
    GuarOptions guar,
    DateTime today, {
    Set<String> preserveKeys = const <String>{},
  }) {
    final _Memory? memory = _memory;
    if (memory != null) {
      return _afterRewriteGate(
        () => memory.rewriteOptions(source, filename, options, guar, today, preserveKeys: preserveKeys),
      );
    }
    return _remote!.rewriteOptions(source, filename, options, guar, today, preserveKeys: preserveKeys);
  }

  Future<String> rewritePlugins(String source, String filename, List<LedgerPlugin> plugins) {
    final _Memory? memory = _memory;
    if (memory != null) return _afterRewriteGate(() => memory.rewritePlugins(source, filename, plugins));
    return _remote!.rewritePlugins(source, filename, plugins);
  }

  Future<AppendOutcome> appendTransaction(String source, String filename, String targetFilename, String snippet) {
    final _Memory? memory = _memory;
    if (memory != null) {
      return Future<AppendOutcome>.microtask(
        () => memory.appendTransaction(source, filename, targetFilename, snippet),
      );
    }
    return _afterRewriteGate(() => _remote!.appendTransaction(source, filename, targetFilename, snippet));
  }

  Future<T> _afterRewriteGate<T>(FutureOr<T> Function() work) {
    final Completer<void>? gate = debugLedgerRewriteGate;
    if (gate == null) return Future<T>.microtask(work);
    return gate.future.then((_) => work());
  }

  Future<void> close() {
    final _RemoteMemory? remote = _remote;
    if (remote == null) return Future<void>.value();
    return remote.close();
  }
}

class _Memory {
  String? _source;
  String? _filename;
  parser.ParsedLedger? _parsed;
  LedgerSnapshot? _snapshot;
  Map<String, String> _includes = const <String, String>{};

  LedgerSnapshot prepare(String source, String filename) {
    if (_snapshot != null && _source == source && _filename == filename && _includesUnchanged()) return _snapshot!;
    final _IncludeRead full = _parseWithIncludes(source, filename);
    if (full.read.isEmpty) {
      // Without includes one parse serves both booking and the later rewrites.
      _parsed = full.parsed;
      _source = source;
      _filename = filename;
      _snapshot = prepareLedger(source, filename: filename, parsed: full.parsed);
      _includes = const <String, String>{};
      return _snapshot!;
    }
    _snapshot = prepareLedger(
      source,
      filename: filename,
      parsed: _parsedFor(source, filename),
      parsedIncludes: full.parsed,
    );
    _includes = full.read;
    return _snapshot!;
  }

  String rewriteOptions(
    String source,
    String filename,
    LedgerOptions options,
    GuarOptions guar,
    DateTime today, {
    Set<String> preserveKeys = const <String>{},
  }) {
    final parser.ParsedLedger parsed = _parsedFor(source, filename);
    return writeLedgerOptions(source, options, guar: guar, today: today, parsed: parsed, preserveKeys: preserveKeys);
  }

  String rewritePlugins(String source, String filename, List<LedgerPlugin> plugins) {
    final parser.ParsedLedger parsed = _parsedFor(source, filename);
    return writeLedgerPlugins(source, plugins, parsed: parsed);
  }

  AppendOutcome appendTransaction(String source, String filename, String targetFilename, String snippet) {
    final bool root = targetFilename == filename;
    final String? original = root ? source : _readFile(targetFilename);
    if (original == null) return const AppendFailed(<String>['Could not read the target file.']);
    final String base = original.isEmpty || original.endsWith('\n') ? original : '$original\n';
    final String text = '$base$snippet';
    final int firstLine = base.split('\n').length;
    final int lastLine = firstLine + snippet.split('\n').length - 2;
    final _IncludeRead full = root
        ? _parseWithIncludes(text, filename)
        : _parseWithIncludes(source, filename, targetPath: targetFilename, targetText: text);
    final Ledger ledger = Book().process(full.parsed, recover: true);
    final List<ProcessingError> errors = switch (ledger) {
      LedgerDirectives(:final List<ProcessingError> errors) => errors,
      LedgerErrors(:final List<ProcessingError> errors) => errors,
    };
    final List<String> snippetErrors = <String>[
      for (final ProcessingError error in errors)
        if (error.location.filename == targetFilename &&
            error.location.linenoBegin >= firstLine &&
            error.location.linenoBegin <= lastLine)
          error.message,
    ];
    if (snippetErrors.isNotEmpty) return AppendFailed(snippetErrors);
    _includes = full.read;
    _snapshot = null;
    return AppendOk(text);
  }

  _IncludeRead _parseWithIncludes(String source, String filename, {String? targetPath, String? targetText}) {
    final Map<String, String> read = <String, String>{};
    final parser.ParsedLedger parsed = const parser.BeancountParser().parse(
      source,
      filename: filename,
      recover: true,
      includes: parser.IncludeController(
        readFile: (String path) {
          final String? text = path == targetPath ? targetText : _readFile(path);
          if (text != null) read[path] = text;
          return text;
        },
      ),
    );
    debugLedgerParses += 1;
    return (read: read, parsed: parsed);
  }

  bool _includesUnchanged() {
    for (final MapEntry<String, String> entry in _includes.entries) {
      if (_readFile(entry.key) != entry.value) return false;
    }
    return true;
  }

  String? _readFile(String path) {
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  parser.ParsedLedger _parsedFor(String source, String filename) {
    final parser.ParsedLedger? parsed = _parsed;
    if (parsed != null && _source == source && _filename == filename) return parsed;
    debugLedgerParses += 1;
    final parser.ParsedLedger ledger = const parser.BeancountParser().parse(
      source,
      filename: filename,
      recover: true,
      followIncludes: false,
    );
    _parsed = ledger;
    _source = source;
    _filename = filename;
    _snapshot = null;
    return ledger;
  }
}

class _PrepareRequest {
  const _PrepareRequest(this.source, this.filename);

  final String source;
  final String filename;
}

class _OptionsRequest {
  const _OptionsRequest(this.source, this.filename, this.options, this.guar, this.today, this.preserveKeys);

  final String source;
  final String filename;
  final LedgerOptions options;
  final GuarOptions guar;
  final DateTime today;
  final List<String> preserveKeys;
}

class _PluginsRequest {
  const _PluginsRequest(this.source, this.filename, this.plugins);

  final String source;
  final String filename;
  final List<LedgerPlugin> plugins;
}

class _AppendRequest {
  const _AppendRequest(this.source, this.filename, this.targetFilename, this.snippet);

  final String source;
  final String filename;
  final String targetFilename;
  final String snippet;
}

class _Failure {
  const _Failure(this.kind, this.message);

  final String kind;
  final String message;
}

class _RemoteMemory {
  SendPort? _send;
  Future<SendPort>? _opening;
  Isolate? _isolate;

  Future<LedgerSnapshot> prepare(String source, String filename) =>
      _call<LedgerSnapshot>(_PrepareRequest(source, filename));

  Future<String> rewriteOptions(
    String source,
    String filename,
    LedgerOptions options,
    GuarOptions guar,
    DateTime today, {
    Set<String> preserveKeys = const <String>{},
  }) => _call<String>(
    _OptionsRequest(source, filename, options, guar, today, preserveKeys.toList(growable: false)),
  );

  Future<String> rewritePlugins(String source, String filename, List<LedgerPlugin> plugins) =>
      _call<String>(_PluginsRequest(source, filename, plugins));

  Future<AppendOutcome> appendTransaction(String source, String filename, String targetFilename, String snippet) =>
      _call<AppendOutcome>(_AppendRequest(source, filename, targetFilename, snippet));

  Future<void> close() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _send = null;
    _opening = null;
  }

  Future<SendPort> _port() {
    final SendPort? send = _send;
    if (send != null) return Future<SendPort>.value(send);
    return _opening ??= _open();
  }

  Future<SendPort> _open() async {
    final ReceivePort receive = ReceivePort();
    _isolate = await Isolate.spawn(_ledgerIsolate, receive.sendPort);
    final SendPort send = await receive.first as SendPort;
    receive.close();
    _send = send;
    return send;
  }

  Future<T> _call<T>(Object request) async {
    final SendPort send = await _port();
    final ReceivePort reply = ReceivePort();
    send.send(<Object?>[request, reply.sendPort]);
    final Object? value = await reply.first;
    reply.close();
    if (value is _Failure) {
      switch (value.kind) {
        case 'format':
          throw FormatException(value.message);
        default:
          throw FormatException(value.message);
      }
    }
    return value as T;
  }
}

void _ledgerIsolate(SendPort send) {
  final ReceivePort receive = ReceivePort();
  final _Memory memory = _Memory();
  send.send(receive.sendPort);
  receive.listen((Object? message) {
    final List<Object?> pair = message! as List<Object?>;
    final SendPort reply = pair[1]! as SendPort;
    try {
      reply.send(_answer(memory, pair[0]));
    } on FormatException catch (error) {
      reply.send(_Failure('format', error.message));
    }
  });
}

Object _answer(_Memory memory, Object? request) {
  switch (request) {
    case _PrepareRequest(:final String source, :final String filename):
      return memory.prepare(source, filename);
    case _OptionsRequest(
      :final String source,
      :final String filename,
      :final LedgerOptions options,
      :final GuarOptions guar,
      :final DateTime today,
      :final List<String> preserveKeys,
    ):
      return memory.rewriteOptions(
        source,
        filename,
        options,
        guar,
        today,
        preserveKeys: preserveKeys.toSet(),
      );
    case _PluginsRequest(:final String source, :final String filename, :final List<LedgerPlugin> plugins):
      return memory.rewritePlugins(source, filename, plugins);
    case _AppendRequest(
      :final String source,
      :final String filename,
      :final String targetFilename,
      :final String snippet,
    ):
      return memory.appendTransaction(source, filename, targetFilename, snippet);
    default:
      throw ArgumentError('Unexpected ledger work');
  }
}
