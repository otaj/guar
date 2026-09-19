// Discovers booked golden fixtures and compares Book.process to Processed* txtpb.

import 'dart:io';
import 'dart:typed_data';

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/src/ledger.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:protobean/protobean.dart' as pb;
import 'package:protobuf/protobuf.dart' show TextFormatExtension;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../mapping/domain_to_proto.dart';

const int _kindProcessedDirectives = 0x11;
const int _kindProcessedErrors = 0x12;
const int _kindProcessedLedger = 0x13;

void main() {
  final Map<String, String> skips = _loadSkips(File('test/harness/skips.yaml'));
  final List<File> fixtures = <File>[
    for (final Directory root in <Directory>[Directory('test/cases')])
      if (root.existsSync())
        ...root.listSync().whereType<File>().where((File file) => file.path.endsWith('.beancount')),
  ]..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File beanFile in fixtures) {
    final String stem = _stemFor(beanFile);
    final File txtpbFile = File('${beanFile.path.substring(0, beanFile.path.length - '.beancount'.length)}.txtpb');
    final String? skipReason = skips[stem];
    test(stem, () async {
      if (!txtpbFile.existsSync()) {
        fail('missing golden ${txtpbFile.path}');
      }
      final _ExpectedGolden expected = await _loadExpected(txtpbFile);
      final String source = await beanFile.readAsString();
      final ParsedLedger parsed = const BeancountParser().parse(source, filename: beanFile.path);
      final Ledger booked = Book().process(parsed);
      final pb.ProcessedLedger actual = ledgerToProto(booked);
      _expectSame(actual, expected);
    }, skip: skipReason);
  }
}

void _expectSame(pb.ProcessedLedger actual, _ExpectedGolden expected) {
  switch (expected) {
    case _ExpectedDirectives(:final pb.ProcessedDirectives directives):
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
    case _ExpectedErrors(:final pb.Errors errors):
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
    case _ExpectedLedger(:final pb.ProcessedLedger ledger):
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
    return <String, String>{};
  }
  final YamlMap yaml = loadYaml(file.readAsStringSync()) as YamlMap;
  final YamlList unmigrated = yaml['unmigrated'] as YamlList? ?? YamlList();
  final YamlList product = yaml['product'] as YamlList? ?? YamlList();
  final Map<String, String> skips = <String, String>{};
  for (final dynamic entry in unmigrated) {
    skips[entry as String] = 'unmigrated prototxt';
  }
  for (final dynamic entry in product) {
    final YamlMap map = entry as YamlMap;
    skips[map['case'] as String] = map['reason'] as String;
  }
  return skips;
}

String _stemFor(File beanFile) {
  final String relative = beanFile.path.replaceFirst(RegExp('^test/'), '');
  return relative.substring(0, relative.length - '.beancount'.length);
}

Future<_ExpectedGolden> _loadExpected(File txtpbFile) async {
  final ProcessResult result = await Process.run(
    'uv',
    <String>['run', 'tool/txtpb_to_pb.py', '--processed', txtpbFile.absolute.path],
    workingDirectory: _workspaceRoot().path,
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) {
    fail('failed to load ${txtpbFile.path}: ${result.stderr}');
  }
  final dynamic bytes = result.stdout;
  if (bytes is! List<int>) {
    fail('txtpb loader produced non-binary stdout for ${txtpbFile.path}');
  }
  if (bytes.isEmpty) {
    fail('txtpb loader produced empty stdout for ${txtpbFile.path}');
  }
  final int kind = bytes.first;
  final Uint8List payload = Uint8List.fromList(bytes.sublist(1));
  return switch (kind) {
    _kindProcessedDirectives => _ExpectedDirectives(pb.ProcessedDirectives.fromBuffer(payload)),
    _kindProcessedErrors => _ExpectedErrors(pb.Errors.fromBuffer(payload)),
    _kindProcessedLedger => _ExpectedLedger(pb.ProcessedLedger.fromBuffer(payload)),
    _ => fail('unknown golden kind 0x${kind.toRadixString(16)} for ${txtpbFile.path}'),
  };
}

Directory _workspaceRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() && File('${dir.path}/tool/txtpb_to_pb.py').existsSync()) {
      return dir;
    }
    final Directory parent = dir.parent;
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
