// Entry point that turns Beancount source text into a ParsedLedger.

import 'dart:io';

import 'package:guar_parser/src/domain/domain.dart';
import 'package:guar_parser/src/parser/diff.dart';
import 'package:guar_parser/src/parser/export.dart';
import 'package:guar_parser/src/parser/grammar.dart';
import 'package:guar_parser/src/parser/include.dart';
import 'package:guar_parser/src/parser/insert.dart';
import 'package:guar_parser/src/parser/splice.dart';

class BeancountParser {
  const BeancountParser();

  ParsedLedger parse(String source, {String filename = '', bool recover = false}) =>
      BeancountGrammar(filename: filename, includes: IncludeController.io(), recover: recover).parse(source);

  ParsedLedger splice(
    ParsedLedger ledger,
    String snippet, {
    required String filename,
    required int startLine,
    required int endLine,
  }) => spliceLedger(ledger, snippet, filename: filename, startLine: startLine, endLine: endLine);

  String export(ParsedLedger ledger) => exportLedger(ledger);

  void exportToFile(ParsedLedger ledger, File file, {required bool overwrite}) {
    writeExportedLedger(ledger, file, overwrite: overwrite);
  }

  ParsedLedger insert(ParsedLedger ledger, ParsedDirective directive) => insertDirective(ledger, directive);

  ParsedLedger insertOption(ParsedLedger ledger, String key, String value) => insertOptionSetting(ledger, key, value);

  ParsedLedger insertPlugin(ParsedLedger ledger, String name, {String? config}) =>
      insertPluginSetting(ledger, name, config: config);

  LedgerDiff diff(ParsedLedger left, ParsedLedger right, {required bool considerLocations}) =>
      diffLedgers(left, right, considerLocations: considerLocations);
}
