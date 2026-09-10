// Entry point that turns Beancount source text into a ParsedLedger.

import '../domain/domain.dart';
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
}
