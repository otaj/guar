// Split postings onto per-posting effective dates via holding accounts.

import 'dart:math';

import 'package:guar_domain/guar_domain.dart';

import '../../plugin.dart';
import '../helpers.dart';
import 'common.dart';

const _defaultHold = {
  'Expenses': {'earlier': 'Liabilities:Hold:Expenses', 'later': 'Assets:Hold:Expenses'},
  'Income': {'earlier': 'Assets:Hold:Income', 'later': 'Liabilities:Hold:Income'},
};

BookPluginResult effectiveDate(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final holding = _holdingAccounts(config);
  if (holding == null) {
    return configError(directives, 'Invalid configuration for effective_date plugin; skipping.');
  }
  final errors = <ProcessingError>[];
  final interesting = <Directive>[];
  final filtered = <Directive>[];
  for (final directive in directives) {
    final transaction = transactionOf(directive);
    if (transaction == null || !_hasValidEffectiveDate(transaction)) {
      filtered.add(directive);
      continue;
    }
    if (_hasMeaninglessEffectiveDate(directive, transaction)) {
      errors.add(
        ProcessingError(message: 'Effective and actual dates are identical', location: directiveLocation(directive)),
      );
      filtered.add(directive);
      continue;
    }
    interesting.add(directive);
  }

  final random = Random();
  final linked = [for (final directive in interesting) _withLink(directive, random)];
  final newAccounts = <String>{};
  final created = <Directive>[];
  for (final directive in linked) {
    final transaction = transactionOf(directive)!;
    final modified = <Posting>[];
    for (final posting in transaction.postings) {
      final date = metaDate(posting.meta, 'effective_date');
      if (date == null) {
        modified.add(posting);
        continue;
      }
      String? found;
      for (final prefix in holding.keys) {
        if (posting.account.name.startsWith(prefix)) found = prefix;
      }
      if (found == null) {
        modified.add(posting);
        continue;
      }
      final when = compareBeanDate(date, directive.date) > 0 ? 'later' : 'earlier';
      final holdPrefix = holding[found]![when]!;
      final holdAccount = posting.account.name.replaceAll(found, holdPrefix);
      newAccounts.add(holdAccount);
      final holdPosting = posting.copyWith(account: rewriteAccount(holdAccount, options));
      modified.add(holdPosting);
      created.add(
        _effectiveEntry(directive, date, _cleaned(holdPosting.copyWith(units: -posting.units)), _cleaned(posting)),
      );
    }
    created.add(replaceTransaction(directive, transaction.copyWith(postings: modified)));
  }
  return (
    directives: [...createOpenDirectives(newAccounts, directives, options), ...filtered, ...created],
    errors: errors,
  );
}

Map<String, Map<String, String>>? _holdingAccounts(String? config) {
  final parsed = parseConfigMap(config);
  if (parsed.error != null) return null;
  if (parsed.map!.isEmpty) return _defaultHold;
  final holding = <String, Map<String, String>>{};
  for (final entry in parsed.map!.entries) {
    if (entry.key is! String || entry.value is! Map) return null;
    final inner = entry.value! as Map<Object?, Object?>;
    holding[entry.key! as String] = {
      for (final item in inner.entries)
        if (item.key is String && item.value is String) item.key! as String: item.value! as String,
    };
  }
  return holding;
}

bool _hasValidEffectiveDate(Transaction transaction) =>
    transaction.postings.any((posting) => metaDate(posting.meta, 'effective_date') != null);

bool _hasMeaninglessEffectiveDate(Directive directive, Transaction transaction) {
  for (final posting in transaction.postings) {
    final date = metaDate(posting.meta, 'effective_date');
    if (date != null && compareBeanDate(date, directive.date) == 0) return true;
  }
  return false;
}

Directive _withLink(Directive directive, Random random) {
  final transaction = transactionOf(directive)!;
  final datePart = '${directive.date}'.replaceAll('-', '').substring(2);
  final suffix = String.fromCharCodes(List.generate(3, (_) => 97 + random.nextInt(26)));
  return replaceTransaction(
    directive,
    transaction.copyWith(
      links: [
        ...transaction.links,
        Link(name: 'edate-$datePart-$suffix'),
      ],
    ),
  );
}

Posting _cleaned(Posting posting) => posting.copyWith(meta: metaWithout(posting.meta, 'effective_date'));

Directive _effectiveEntry(Directive original, BeanDate date, Posting hold, Posting originalPosting) {
  final transaction = transactionOf(original)!;
  return original.copyWith(
    date: date,
    meta: metaWith(original.meta, 'original_date', MetaValue.date(original.date)),
    body: DirectiveBody.transaction(transaction.copyWith(postings: [hold, originalPosting])),
  );
}
