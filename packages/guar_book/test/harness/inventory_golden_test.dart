// Discovers .inventory companions and compares LedgerInventory after booking.

import 'dart:io';

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final Map<String, String> skips = _loadSkips(File('test/harness/skips.yaml'));
  final List<File> fixtures = <File>[
    for (final Directory root in <Directory>[Directory('test/cases')])
      if (root.existsSync())
        ...root.listSync().whereType<File>().where((File file) => file.path.endsWith('.inventory')),
  ]..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File inventoryFile in fixtures) {
    final File beanFile = File(
      '${inventoryFile.path.substring(0, inventoryFile.path.length - '.inventory'.length)}.beancount',
    );
    final String stem = _stemFor(beanFile);
    final String? skipReason = skips[stem];
    test(stem, () async {
      if (!beanFile.existsSync()) {
        fail('missing ledger ${beanFile.path}');
      }
      final String source = await beanFile.readAsString();
      final String expected = (await inventoryFile.readAsString()).trimRight();
      final ParsedLedger parsed = const BeancountParser().parse(source, filename: beanFile.path);
      final Ledger booked = Book().process(parsed);
      expect(booked, isA<LedgerDirectives>(), reason: booked.toString());
      final String actual = formatLedgerInventory(inventoryFromLedger(booked));
      expect(actual, expected);
    }, skip: skipReason);
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
