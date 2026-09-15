// Discovers booked golden fixtures and compares Book.process to Processed* txtpb.

import 'dart:io';
import 'dart:typed_data';

import 'package:guar_book/guar_book.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:protobean/protobean.dart' as pb;
import 'package:protobuf/protobuf.dart' show TextFormatExtension;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../mapping/domain_to_proto.dart';

const _kindProcessedDirectives = 0x11;
const _kindProcessedErrors = 0x12;
const _kindProcessedLedger = 0x13;

void main() {
  final skips = _loadSkips(File('test/harness/skips.yaml'));
  final fixtures = <File>[
    for (final root in [Directory('test/cases')])
      if (root.existsSync()) ...root.listSync().whereType<File>().where((file) => file.path.endsWith('.beancount')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  for (final beanFile in fixtures) {
    final stem = _stemFor(beanFile);
    final txtpbFile = File('${beanFile.path.substring(0, beanFile.path.length - '.beancount'.length)}.txtpb');
    final skipReason = skips[stem];
    test(stem, () async {
      if (!txtpbFile.existsSync()) {
        fail('missing golden ${txtpbFile.path}');
      }
      final expected = await _loadExpected(txtpbFile);
      final source = await beanFile.readAsString();
      final parsed = BeancountParser().parse(source, filename: beanFile.path);
      final booked = Book().process(parsed);
      final actual = ledgerToProto(booked);
      _expectSame(actual, expected);
    }, skip: skipReason);
  }
}

void _expectSame(pb.ProcessedLedger actual, _ExpectedGolden expected) {
  switch (expected) {
    case _ExpectedDirectives(:final directives):
      if (!actual.hasDirectives()) {
        fail('actual is errors, expected directives:\n${actual.toTextFormat()}');
      }
      clearProcessedDirectiveLocations(actual.directives);
      clearProcessedDirectiveLocations(directives);
      expect(
        actual.directives.writeToBuffer(),
        equals(directives.writeToBuffer()),
        reason: 'actual:\n${actual.directives.toTextFormat()}\nexpected:\n${directives.toTextFormat()}',
      );
    case _ExpectedErrors(:final errors):
      if (!actual.hasErrors()) {
        fail('actual is directives, expected errors:\n${actual.toTextFormat()}');
      }
      clearErrorLocations(actual.errors);
      clearErrorLocations(errors);
      expect(
        actual.errors.writeToBuffer(),
        equals(errors.writeToBuffer()),
        reason: 'actual:\n${actual.errors.toTextFormat()}\nexpected:\n${errors.toTextFormat()}',
      );
    case _ExpectedLedger(:final ledger):
      if (ledger.hasErrors()) {
        if (!actual.hasErrors()) {
          fail('actual is directives, expected errors:\n${actual.toTextFormat()}');
        }
        clearErrorLocations(actual.errors);
        clearErrorLocations(ledger.errors);
        expect(actual.errors.writeToBuffer(), equals(ledger.errors.writeToBuffer()));
      } else if (ledger.hasDirectives()) {
        if (!actual.hasDirectives()) {
          fail('actual is errors, expected directives:\n${actual.toTextFormat()}');
        }
        clearProcessedDirectiveLocations(actual.directives);
        clearProcessedDirectiveLocations(ledger.directives);
        expect(actual.directives.writeToBuffer(), equals(ledger.directives.writeToBuffer()));
      }
  }
}

Map<String, String> _loadSkips(File file) {
  if (!file.existsSync()) {
    return {};
  }
  final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
  final unmigrated = yaml['unmigrated'] as YamlList? ?? YamlList();
  final product = yaml['product'] as YamlList? ?? YamlList();
  final skips = <String, String>{};
  for (final entry in unmigrated) {
    skips[entry as String] = 'unmigrated prototxt';
  }
  for (final entry in product) {
    final map = entry as YamlMap;
    skips[map['case'] as String] = map['reason'] as String;
  }
  return skips;
}

String _stemFor(File beanFile) {
  final relative = beanFile.path.replaceFirst(RegExp(r'^test/'), '');
  return relative.substring(0, relative.length - '.beancount'.length);
}

Future<_ExpectedGolden> _loadExpected(File txtpbFile) async {
  final result = await Process.run(
    'uv',
    ['run', 'tool/txtpb_to_pb.py', '--processed', txtpbFile.absolute.path],
    workingDirectory: _workspaceRoot().path,
    stdoutEncoding: null,
    stderrEncoding: SystemEncoding(),
  );
  if (result.exitCode != 0) {
    fail('failed to load ${txtpbFile.path}: ${result.stderr}');
  }
  final bytes = result.stdout;
  if (bytes is! List<int>) {
    fail('txtpb loader produced non-binary stdout for ${txtpbFile.path}');
  }
  if (bytes.isEmpty) {
    fail('txtpb loader produced empty stdout for ${txtpbFile.path}');
  }
  final kind = bytes.first;
  final payload = Uint8List.fromList(bytes.sublist(1));
  return switch (kind) {
    _kindProcessedDirectives => _ExpectedDirectives(pb.ProcessedDirectives.fromBuffer(payload)),
    _kindProcessedErrors => _ExpectedErrors(pb.Errors.fromBuffer(payload)),
    _kindProcessedLedger => _ExpectedLedger(pb.ProcessedLedger.fromBuffer(payload)),
    _ => fail('unknown golden kind 0x${kind.toRadixString(16)} for ${txtpbFile.path}'),
  };
}

Directory _workspaceRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() && File('${dir.path}/tool/txtpb_to_pb.py').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate workspace root from ${Directory.current.path}');
    }
    dir = parent;
  }
}

sealed class _ExpectedGolden {}

final class _ExpectedDirectives extends _ExpectedGolden {
  _ExpectedDirectives(this.directives);
  final pb.ProcessedDirectives directives;
}

final class _ExpectedErrors extends _ExpectedGolden {
  _ExpectedErrors(this.errors);
  final pb.Errors errors;
}

final class _ExpectedLedger extends _ExpectedGolden {
  _ExpectedLedger(this.ledger);
  final pb.ProcessedLedger ledger;
}
