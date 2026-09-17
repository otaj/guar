// Match zerosum posting pairs and move them to a matched target account.

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

final Decimal _defaultTolerance = Decimal.parse('0.0099');

BookPluginResult zerosumPlugin(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final parsed = _parse(config);
  if (parsed == null) {
    return configError(directives, 'Invalid configuration for zerosum plugin; skipping.');
  }
  final matched = _zerosum(directives, options, parsed);
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
  final parsed = parseConfigMap(config);
  if (parsed.error != null) return null;
  final map = Map<Object?, Object?>.of(parsed.map!);
  final rawAccounts = map.remove('zerosum_accounts');
  final accounts = <String, ({String target, int dateRange})>{};
  if (rawAccounts is Map<Object?, Object?>) {
    for (final entry in rawAccounts.entries) {
      if (entry.key is! String || entry.value is! List) return null;
      final spec = entry.value! as List<Object?>;
      if (spec.length < 2) return null;
      accounts[entry.key! as String] = (target: spec[0]?.toString() ?? '', dateRange: (spec[1] as num).toInt());
    }
  }
  var replaceFrom = '';
  var replaceTo = '';
  final replace = map.remove('account_name_replace');
  if (replace is List && replace.length >= 2) {
    replaceFrom = replace[0]?.toString() ?? '';
    replaceTo = replace[1]?.toString() ?? '';
  }
  final toleranceValue = map.remove('tolerance');
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
  final current = [...directives];
  final newAccounts = <String>{};
  final random = Random(6);
  const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  String matchId() =>
      String.fromCharCodes(List.generate(20, (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length))));

  void replacePosting(int txnIndex, int postingIndex, Account account, String? id) {
    final transaction = transactionOf(current[txnIndex])!;
    final postings = [...transaction.postings];
    var posting = postings[postingIndex];
    var meta = posting.meta;
    if (id != null && config.matchMetadata) {
      meta = metaWith(meta, config.matchMetadataName, MetaValue.text(id));
    }
    postings[postingIndex] = posting.copyWith(account: account, meta: meta);
    var links = transaction.links;
    if (id != null && config.linkTransactions) {
      links = [...links, Link(name: '${config.linkPrefix}$id')];
    }
    current[txnIndex] = replaceTransaction(current[txnIndex], transaction.copyWith(postings: postings, links: links));
  }

  for (final entry in config.accounts.entries) {
    final zsAccount = entry.key;
    final targetName = entry.value.target.isEmpty
        ? zsAccount.replaceAll(config.replaceFrom, config.replaceTo)
        : entry.value.target;
    final target = rewriteAccount(targetName, options);
    final dateRange = entry.value.dateRange;
    final indices = [
      for (var i = 0; i < current.length; i++)
        if (transactionOf(current[i]) != null) i,
    ];

    for (var i = 0; i < indices.length; i++) {
      var reprocess = true;
      while (reprocess) {
        reprocess = false;
        final txnIndex = indices[i];
        final transaction = transactionOf(current[txnIndex]);
        if (transaction == null) break;
        for (var p = 0; p < transaction.postings.length; p++) {
          if (transaction.postings[p].account.name != zsAccount) continue;
          final posting = transaction.postings[p];
          final maxDate = addDays(current[txnIndex].date, dateRange);
          ({int txn, int posting})? found;
          outer:
          for (var j = i; j < indices.length; j++) {
            final otherIndex = indices[j];
            if (compareBeanDate(current[otherIndex].date, maxDate) > 0) break;
            final other = transactionOf(current[otherIndex]);
            if (other == null) continue;
            for (var q = 0; q < other.postings.length; q++) {
              if (j == i && q == p) continue;
              final candidate = other.postings[q];
              if (candidate.account.name != zsAccount) continue;
              if ((candidate.units.number + posting.units.number).abs() < config.tolerance) {
                found = (txn: otherIndex, posting: q);
                break outer;
              }
            }
          }
          if (found == null) continue;
          final id = config.matchMetadata || config.linkTransactions ? matchId() : null;
          replacePosting(txnIndex, p, target, id);
          replacePosting(found.txn, found.posting, target, id);
          newAccounts.add(targetName);
          reprocess = true;
          break;
        }
      }
    }
  }
  return [...createOpenDirectives(newAccounts, current, options), ...current];
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
  if (!config.flagUnmatched) return (directives: directives, errors: const []);
  final zs = config.accounts.keys.toSet();
  return (
    directives: [
      for (final directive in directives)
        if (transactionOf(directive) case final transaction?)
          transaction.postings.any((posting) => zs.contains(posting.account.name))
              ? replaceTransaction(directive, transaction.copyWith(flag: const Flag.special(SpecialFlag.exclamation)))
              : directive
        else
          directive,
    ],
    errors: const [],
  );
}
