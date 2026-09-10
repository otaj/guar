// Entry point that turns Beancount source text into a ParsedLedger.

import '../domain/domain.dart';
import 'grammar.dart';
import 'include.dart';

class BeancountParser {
  const BeancountParser();

  ParsedLedger parse(String source, {String filename = ''}) {
    return BeancountGrammar(filename: filename, includes: IncludeController.io()).parse(source);
  }
}
