// Discovers .inventory companions and compares LedgerInventory after booking.

import 'dart:io';

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final skips = _loadSkips(File('test/harness/skips.yaml'));
  final fixtures = <File>[
    for (final root in [Directory('test/cases')])
      if (root.existsSync()) ...root.listSync().whereType<File>().where((file) => file.path.endsWith('.inventory')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  for (final inventoryFile in fixtures) {
    final beanFile = File(
      '${inventoryFile.path.substring(0, inventoryFile.path.length - '.inventory'.length)}.beancount',
    );
    final stem = _stemFor(beanFile);
    final skipReason = skips[stem];
    test(stem, () async {
      if (!beanFile.existsSync()) {
        fail('missing ledger ${beanFile.path}');
      }
      final source = await beanFile.readAsString();
      final expected = (await inventoryFile.readAsString()).trimRight();
      final parsed = BeancountParser().parse(source, filename: beanFile.path);
      final booked = Book().process(parsed);
      expect(booked, isA<LedgerDirectives>(), reason: booked.toString());
      final actual = formatLedgerInventory(inventoryFromLedger(booked));
      expect(actual, expected);
    }, skip: skipReason);
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
