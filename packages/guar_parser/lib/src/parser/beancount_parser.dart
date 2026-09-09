// Entry point that turns Beancount source text into a ParsedLedger.

import '../domain/domain.dart';

class BeancountParser {
  const BeancountParser();

  ParsedLedger parse(String source, {String filename = ''}) {
    return ParsedLedger.directives(
      directives: const [],
      info: ProcessingInfo(filename: filename.isEmpty ? null : filename),
    );
  }
}
