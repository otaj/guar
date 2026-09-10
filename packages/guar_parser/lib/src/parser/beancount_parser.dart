// Entry point that turns Beancount source text into a ParsedLedger.

import 'dart:io';

import '../domain/domain.dart';
import 'diff.dart';
import 'export.dart';
import 'grammar.dart';
import 'include.dart';
import 'splice.dart';

class BeancountParser {
  const BeancountParser();

  ParsedLedger parse(String source, {String filename = ''}) {
    return BeancountGrammar(filename: filename, includes: IncludeController.io()).parse(source);
  }

  ParsedLedger splice(
    ParsedLedger ledger,
    String snippet, {
    required String filename,
    required int startLine,
    required int endLine,
  }) {
    return spliceLedger(ledger, snippet, filename: filename, startLine: startLine, endLine: endLine);
  }

  String export(ParsedLedger ledger) => exportLedger(ledger);

  void exportToFile(ParsedLedger ledger, File file, {required bool overwrite}) {
    writeExportedLedger(ledger, file, overwrite: overwrite);
  }

  LedgerDiff diff(ParsedLedger left, ParsedLedger right, {required bool considerLocations}) {
    return diffLedgers(left, right, considerLocations: considerLocations);
  }
}
