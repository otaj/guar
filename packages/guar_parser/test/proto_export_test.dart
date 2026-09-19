// Protobean binary and text export of a ParsedLedger.

import 'dart:io';

import 'package:guar_parser/guar_parser.dart';
import 'package:guar_parser/proto.dart';
import 'package:protobean/protobean.dart' as pb;
import 'package:protobuf/protobuf.dart' show TextFormatExtension;
import 'package:test/test.dart';

void main() {
  const BeancountParser parser = BeancountParser();

  test('exportProto maps a successful parse onto protobean ParsedLedger', () {
    final ParsedLedger ledger = parser.parse('2014-01-01 open Assets:Cash\n', filename: 'ledger.beancount');
    final pb.ParsedLedger proto = parser.exportProto(ledger);
    expect(proto.hasDirectives(), isTrue);
    expect(proto.directives.directives, hasLength(1));
    expect(proto.directives.directives.single.open.account.name, 'Assets:Cash');
    expect(proto.info.filename, 'ledger.beancount');
  });

  test('does not populate Beancount option defaults when the source omitted them', () {
    final ParsedLedger ledger = parser.parse('2014-01-01 close Assets:Cash\n', filename: 'tiny.beancount');
    final LedgerOptions options = switch (ledger) {
      ParsedLedgerDirectives(:final LedgerOptions options) => options,
      ParsedLedgerErrors(:final List<ParseError> errors) => throw TestFailure(
        errors.map((ParseError e) => e.message).join('\n'),
      ),
    };
    expect(options.title, isNull);
    expect(options.conversionCurrency, isNull);
    expect(options.accountPrefixes.assets, isNull);
    final String text = parser.exportProtoText(ledger);
    expect(text, isNot(contains('Untitled')));
    expect(text, isNot(contains('Opening-Balances')));
    expect(text, isNot(contains('conversion_currency')));
    expect(text, isNot(contains('account_prefixes')));
  });

  test('exportProto maps parse errors onto protobean Errors', () {
    final pb.ParsedLedger proto = parser.exportProto(parser.parse('not a directive\n', filename: 'ledger.beancount'));
    expect(proto.hasErrors(), isTrue);
    expect(proto.errors.errors, isNotEmpty);
  });

  test('binary and text formats round-trip the same message', () {
    final ParsedLedger ledger = parser.parse(
      'option "title" "Proto"\n2014-01-01 close Assets:Cash\n',
      filename: 'ledger.beancount',
    );
    final pb.ParsedLedger original = parser.exportProto(ledger);
    final pb.ParsedLedger fromBytes = pb.ParsedLedger.fromBuffer(parser.exportProtoBytes(ledger));
    expect(fromBytes.writeToBuffer(), original.writeToBuffer());
    expect(parser.exportProtoText(ledger), original.toTextFormat());
    expect(parser.exportProtoText(ledger), contains('title: "Proto"'));
  });

  test('exportProtoToFile writes binary or text and requires overwrite for non-empty files', () {
    final Directory dir = Directory.systemTemp.createTempSync('guar_proto_export_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File dest = File('${dir.path}/out.pb');
    final ParsedLedger ledger = parser.parse('2014-01-01 commodity USD\n', filename: 'ledger.beancount');

    parser.exportProtoToFile(ledger, dest, overwrite: false, format: ProtoExportFormat.binary);
    expect(pb.ParsedLedger.fromBuffer(dest.readAsBytesSync()).directives.directives.single.hasCommodity(), isTrue);

    dest.writeAsBytesSync(const <int>[1, 2, 3]);
    expect(
      () => parser.exportProtoToFile(ledger, dest, overwrite: false, format: ProtoExportFormat.binary),
      throwsA(isA<StateError>()),
    );

    parser.exportProtoToFile(ledger, dest, overwrite: true, format: ProtoExportFormat.text);
    expect(dest.readAsStringSync(), contains('commodity'));
  });
}
