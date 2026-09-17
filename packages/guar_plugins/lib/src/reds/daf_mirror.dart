// Mirror DAF asset transactions onto the matching liability accounts.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import '../config_literal.dart';
import 'common.dart';

const _metaGenerated = 'daf_mirror_generated';
const _defaultPrefix = 'Assets:DAF';
const _defaultPayeePrefix = 'Mirror ';

BookPluginResult dafMirror(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final parsed = _parseConfig(config);
  final out = <Directive>[];
  for (final directive in directives) {
    out.add(directive);
    final mirrored = _mirror(directive, parsed.prefix, parsed.payeePrefix, options);
    if (mirrored != null) out.add(mirrored);
  }
  return (directives: out, errors: const []);
}

({String prefix, String payeePrefix}) _parseConfig(String? config) {
  if (config == null || config.trim().isEmpty) {
    return (prefix: _defaultPrefix, payeePrefix: _defaultPayeePrefix);
  }
  final parsed = parseConfigLiteral(config);
  final value = parsed.value;
  if (parsed.error != null || value == null) {
    return (prefix: config.trim().isEmpty ? _defaultPrefix : config.trim(), payeePrefix: _defaultPayeePrefix);
  }
  if (value is Map<Object?, Object?>) {
    final prefix = value['account_prefix']?.toString().trim();
    return (
      prefix: (prefix == null || prefix.isEmpty) ? _defaultPrefix : prefix,
      payeePrefix: value['payee_prefix']?.toString() ?? _defaultPayeePrefix,
    );
  }
  final prefix = value.toString().trim();
  return (prefix: prefix.isEmpty ? _defaultPrefix : prefix, payeePrefix: _defaultPayeePrefix);
}

Directive? _mirror(Directive directive, String prefix, String payeePrefix, LedgerOptions options) {
  final transaction = transactionOf(directive);
  if (transaction == null) return null;
  if (metaFlag(directive.meta, _metaGenerated)) return null;
  final names = [for (final posting in transaction.postings) posting.account.name];
  if (!names.any((name) => name.startsWith(prefix))) return null;
  if (names.any((name) => name.startsWith('Assets:') && !name.startsWith(prefix))) return null;

  var payee = transaction.payee;
  var narration = transaction.narration;
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
        postings: [for (final posting in transaction.postings) _mirrorPosting(posting, options)],
      ),
    ),
  );
}

Posting _mirrorPosting(Posting posting, LedgerOptions options) {
  return posting.copyWith(
    account: rewriteAccount(_mirrorAccount(posting.account.name), options),
    units: -posting.units,
  );
}

String _mirrorAccount(String name) {
  if (name.startsWith('Assets:')) return 'Liabilities:${name.substring('Assets:'.length)}';
  if (name.startsWith('Liabilities:')) return 'Assets:${name.substring('Liabilities:'.length)}';
  return name;
}
