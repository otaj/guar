// Mirror DAF asset transactions onto the matching liability accounts.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

const String _metaGenerated = 'daf_mirror_generated';
const String _defaultPrefix = 'Assets:DAF';
const String _defaultPayeePrefix = 'Mirror ';

BookPluginResult dafMirror(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final ({String payeePrefix, String prefix}) parsed = _parseConfig(config);
  final List<Directive> out = <Directive>[];
  for (final Directive directive in directives) {
    out.add(directive);
    final Directive? mirrored = _mirror(directive, parsed.prefix, parsed.payeePrefix, options);
    if (mirrored != null) out.add(mirrored);
  }
  return (directives: out, errors: const <ProcessingError>[]);
}

({String prefix, String payeePrefix}) _parseConfig(String? config) {
  if (config == null || config.trim().isEmpty) {
    return (prefix: _defaultPrefix, payeePrefix: _defaultPayeePrefix);
  }
  final ConfigLiteral parsed = parseConfigLiteral(config);
  final Object? value = parsed.value;
  if (parsed.error != null || value == null) {
    return (prefix: config.trim().isEmpty ? _defaultPrefix : config.trim(), payeePrefix: _defaultPayeePrefix);
  }
  if (value is Map<Object?, Object?>) {
    final String? prefix = value['account_prefix']?.toString().trim();
    return (
      prefix: (prefix == null || prefix.isEmpty) ? _defaultPrefix : prefix,
      payeePrefix: value['payee_prefix']?.toString() ?? _defaultPayeePrefix,
    );
  }
  final String prefix = value.toString().trim();
  return (prefix: prefix.isEmpty ? _defaultPrefix : prefix, payeePrefix: _defaultPayeePrefix);
}

Directive? _mirror(Directive directive, String prefix, String payeePrefix, LedgerOptions options) {
  final Transaction? transaction = transactionOf(directive);
  if (transaction == null) return null;
  if (metaFlag(directive.meta, _metaGenerated)) return null;
  final List<String> names = <String>[for (final Posting posting in transaction.postings) posting.account.name];
  if (!names.any((String name) => name.startsWith(prefix))) return null;
  if (names.any((String name) => name.startsWith('Assets:') && !name.startsWith(prefix))) return null;

  String? payee = transaction.payee;
  String narration = transaction.narration;
  if (payee != null && payee.isNotEmpty) {
    payee = '$payeePrefix$payee';
  } else if (narration.isNotEmpty) {
    narration = '$payeePrefix$narration';
  }

  return directive.copyWith(
    meta: metaWith(directive.meta, _metaGenerated, const MetaValue.boolean(true)),
    body: DirectiveBody.transaction(
      transaction.copyWith(
        payee: payee,
        narration: narration,
        postings: <Posting>[for (final Posting posting in transaction.postings) _mirrorPosting(posting, options)],
      ),
    ),
  );
}

Posting _mirrorPosting(Posting posting, LedgerOptions options) => posting.copyWith(
  account: rewriteAccount(_mirrorAccount(posting.account.name), options),
  units: -posting.units,
);

String _mirrorAccount(String name) {
  if (name.startsWith('Assets:')) return 'Liabilities:${name.substring('Assets:'.length)}';
  if (name.startsWith('Liabilities:')) return 'Assets:${name.substring('Liabilities:'.length)}';
  return name;
}
