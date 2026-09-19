// Match zerosum posting pairs and move them to a matched target account.

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

final Decimal _defaultTolerance = Decimal.parse('0.0099');

BookPluginResult zerosumPlugin(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final ({
    Map<String, ({int dateRange, String target})> accounts,
    bool flagUnmatched,
    String linkPrefix,
    bool linkTransactions,
    bool matchMetadata,
    String matchMetadataName,
    String replaceFrom,
    String replaceTo,
    Decimal tolerance,
  })?
  parsed = _parse(config);
  if (parsed == null) {
    return configError(directives, 'Invalid configuration for zerosum plugin; skipping.');
  }
  final List<Directive> matched = _zerosum(directives, options, info, parsed);
  return _flagUnmatched(matched, parsed);
}

({
  Map<String, ({String target, int dateRange})> accounts,
  String replaceFrom,
  String replaceTo,
  Decimal tolerance,
  bool matchMetadata,
  String matchMetadataName,
  bool linkTransactions,
  String linkPrefix,
  bool flagUnmatched,
})?
_parse(String? config) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null) return null;
  final Map<Object?, Object?> map = Map<Object?, Object?>.of(parsed.map!);
  final Object? rawAccounts = map.remove('zerosum_accounts');
  final Map<String, ({int dateRange, String target})> accounts = <String, ({String target, int dateRange})>{};
  if (rawAccounts is Map<Object?, Object?>) {
    for (final MapEntry<Object?, Object?> entry in rawAccounts.entries) {
      if (entry.key is! String || entry.value is! List) return null;
      final List<Object?> spec = entry.value! as List<Object?>;
      if (spec.length < 2) return null;
      accounts[entry.key! as String] = (target: spec[0]?.toString() ?? '', dateRange: (spec[1]! as num).toInt());
    }
  }
  String replaceFrom = '';
  String replaceTo = '';
  final Object? replace = map.remove('account_name_replace');
  if (replace is List && replace.length >= 2) {
    replaceFrom = replace[0]?.toString() ?? '';
    replaceTo = replace[1]?.toString() ?? '';
  }
  final Object? toleranceValue = map.remove('tolerance');
  return (
    accounts: accounts,
    replaceFrom: replaceFrom,
    replaceTo: replaceTo,
    tolerance: toleranceValue == null ? _defaultTolerance : toDecimal(toleranceValue),
    matchMetadata: map.remove('match_metadata') == true,
    matchMetadataName: map.remove('match_metadata_name')?.toString() ?? 'match_id',
    linkTransactions: map.remove('link_transactions') == true,
    linkPrefix: map.remove('link_prefix')?.toString() ?? 'ZeroSum.',
    flagUnmatched: map.remove('flag_unmatched') == true,
  );
}

List<Directive> _zerosum(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  ({
    Map<String, ({String target, int dateRange})> accounts,
    String replaceFrom,
    String replaceTo,
    Decimal tolerance,
    bool matchMetadata,
    String matchMetadataName,
    bool linkTransactions,
    String linkPrefix,
    bool flagUnmatched,
  })
  config,
) {
  final List<Directive> current = <Directive>[...directives];
  final Set<String> newAccounts = <String>{};
  final Random random = Random(6);
  const String alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  String matchId() =>
      String.fromCharCodes(List<int>.generate(20, (int _) => alphabet.codeUnitAt(random.nextInt(alphabet.length))));

  void replacePosting(int txnIndex, int postingIndex, Account account, String? id) {
    final Transaction transaction = transactionOf(current[txnIndex])!;
    final List<Posting> postings = <Posting>[...transaction.postings];
    final Posting posting = postings[postingIndex];
    Meta meta = posting.meta;
    if (id != null && config.matchMetadata) {
      meta = metaWith(meta, config.matchMetadataName, MetaValue.text(id));
    }
    postings[postingIndex] = posting.copyWith(account: account, meta: meta);
    List<Link> links = transaction.links;
    if (id != null && config.linkTransactions) {
      links = <Link>[...links, Link(name: '${config.linkPrefix}$id')];
    }
    current[txnIndex] = replaceTransaction(current[txnIndex], transaction.copyWith(postings: postings, links: links));
  }

  for (final MapEntry<String, ({int dateRange, String target})> entry in config.accounts.entries) {
    final String zsAccount = entry.key;
    final String targetName = entry.value.target.isEmpty
        ? zsAccount.replaceAll(config.replaceFrom, config.replaceTo)
        : entry.value.target;
    final Account target = rewriteAccount(targetName, options);
    final int dateRange = entry.value.dateRange;
    final List<int> indices = <int>[
      for (int i = 0; i < current.length; i++)
        if (transactionOf(current[i]) != null) i,
    ];

    for (int i = 0; i < indices.length; i++) {
      bool reprocess = true;
      while (reprocess) {
        reprocess = false;
        final int txnIndex = indices[i];
        final Transaction? transaction = transactionOf(current[txnIndex]);
        if (transaction == null) break;
        for (int p = 0; p < transaction.postings.length; p++) {
          if (transaction.postings[p].account.name != zsAccount) continue;
          final Posting posting = transaction.postings[p];
          final BeanDate maxDate = addDays(current[txnIndex].date, dateRange);
          ({int txn, int posting})? found;
          outer:
          for (int j = i; j < indices.length; j++) {
            final int otherIndex = indices[j];
            if (compareBeanDate(current[otherIndex].date, maxDate) > 0) break;
            final Transaction? other = transactionOf(current[otherIndex]);
            if (other == null) continue;
            for (int q = 0; q < other.postings.length; q++) {
              if (j == i && q == p) continue;
              final Posting candidate = other.postings[q];
              if (candidate.account.name != zsAccount) continue;
              if ((candidate.units.number + posting.units.number).abs() < config.tolerance) {
                found = (txn: otherIndex, posting: q);
                break outer;
              }
            }
          }
          if (found == null) continue;
          final String? id = config.matchMetadata || config.linkTransactions ? matchId() : null;
          replacePosting(txnIndex, p, target, id);
          replacePosting(found.txn, found.posting, target, id);
          newAccounts.add(targetName);
          reprocess = true;
          break;
        }
      }
    }
  }
  return <Directive>[...createOpenDirectives(newAccounts, current, options, info), ...current];
}

BookPluginResult _flagUnmatched(
  List<Directive> directives,
  ({
    Map<String, ({String target, int dateRange})> accounts,
    String replaceFrom,
    String replaceTo,
    Decimal tolerance,
    bool matchMetadata,
    String matchMetadataName,
    bool linkTransactions,
    String linkPrefix,
    bool flagUnmatched,
  })
  config,
) {
  if (!config.flagUnmatched) return (directives: directives, errors: const <ProcessingError>[]);
  final Set<String> zs = config.accounts.keys.toSet();
  return (
    directives: <Directive>[
      for (final Directive directive in directives)
        if (transactionOf(directive) case final Transaction transaction?)
          transaction.postings.any((Posting posting) => zs.contains(posting.account.name))
              ? replaceTransaction(directive, transaction.copyWith(flag: const Flag.special(SpecialFlag.exclamation)))
              : directive
        else
          directive,
    ],
    errors: const <ProcessingError>[],
  );
}
