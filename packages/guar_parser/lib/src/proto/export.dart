// Public protobean export of a parsed ledger (binary and text).

import 'dart:io';
import 'dart:typed_data';

import 'package:guar_parser/guar_parser.dart';
import 'package:protobuf/protobuf.dart' show TextFormatExtension;
import 'package:protobean/protobean.dart' as pb;

import 'domain_to_proto.dart';

enum ProtoExportFormat { binary, text }

extension BeancountProtoExport on BeancountParser {
  pb.ParsedLedger exportProto(ParsedLedger ledger) => domainToProto(ledger);

  Uint8List exportProtoBytes(ParsedLedger ledger) => Uint8List.fromList(exportProto(ledger).writeToBuffer());

  String exportProtoText(ParsedLedger ledger) => exportProto(ledger).toTextFormat();

  void exportProtoToFile(ParsedLedger ledger, File file, {required bool overwrite, required ProtoExportFormat format}) {
    if (file.existsSync()) {
      final existing = file.readAsBytesSync();
      if (existing.isNotEmpty && !overwrite) {
        throw StateError('refusing to overwrite ${file.path}');
      }
    }
    switch (format) {
      case ProtoExportFormat.binary:
        file.writeAsBytesSync(exportProtoBytes(ledger));
      case ProtoExportFormat.text:
        file.writeAsStringSync(exportProtoText(ledger));
    }
  }
}
