// Books the text of the open ledger file.

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as parser;

Ledger bookLedger(String source, {String filename = ''}) {
  // Included paths are not files the app has opened. Keep a directive when a later check fails.
  final parser.ParsedLedger parsed = const parser.BeancountParser().parse(
    source,
    filename: filename,
    recover: true,
    followIncludes: false,
  );
  return Book().process(parsed, recover: true);
}
