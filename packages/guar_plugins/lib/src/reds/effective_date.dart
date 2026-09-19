// Split postings onto per-posting effective dates via holding accounts.

import 'dart:math';

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

const Map<String, Map<String, String>> _defaultHold = <String, Map<String, String>>{
  'Expenses': <String, String>{'earlier': 'Liabilities:Hold:Expenses', 'later': 'Assets:Hold:Expenses'},
  'Income': <String, String>{'earlier': 'Assets:Hold:Income', 'later': 'Liabilities:Hold:Income'},
};

BookPluginResult effectiveDate(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final Map<String, Map<String, String>>? holding = _holdingAccounts(config);
  if (holding == null) {
    return configError(directives, 'Invalid configuration for effective_date plugin; skipping.');
  }
  final List<ProcessingError> errors = <ProcessingError>[];
  final List<Directive> interesting = <Directive>[];
  final List<Directive> filtered = <Directive>[];
  for (final Directive directive in directives) {
    final Transaction? transaction = transactionOf(directive);
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

  final Random random = Random();
  final List<Directive> linked = <Directive>[
    for (final Directive directive in interesting) _withLink(directive, random),
  ];
  final Set<String> newAccounts = <String>{};
  final List<Directive> created = <Directive>[];
  for (final Directive directive in linked) {
    final Transaction transaction = transactionOf(directive)!;
    final List<Posting> modified = <Posting>[];
    for (final Posting posting in transaction.postings) {
      final BeanDate? date = metaDate(posting.meta, 'effective_date');
      if (date == null) {
        modified.add(posting);
        continue;
      }
      String? found;
      for (final String prefix in holding.keys) {
        if (posting.account.name.startsWith(prefix)) found = prefix;
      }
      if (found == null) {
        modified.add(posting);
        continue;
      }
      final String when = compareBeanDate(date, directive.date) > 0 ? 'later' : 'earlier';
      final String holdPrefix = holding[found]![when]!;
      final String holdAccount = posting.account.name.replaceAll(found, holdPrefix);
      newAccounts.add(holdAccount);
      final Posting holdPosting = posting.copyWith(account: rewriteAccount(holdAccount, options));
      modified.add(holdPosting);
      created.add(
        _effectiveEntry(directive, date, _cleaned(holdPosting.copyWith(units: -posting.units)), _cleaned(posting)),
      );
    }
    created.add(replaceTransaction(directive, transaction.copyWith(postings: modified)));
  }
  return (
    directives: <Directive>[...createOpenDirectives(newAccounts, directives, options, info), ...filtered, ...created],
    errors: errors,
  );
}

Map<String, Map<String, String>>? _holdingAccounts(String? config) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null) return null;
  if (parsed.map!.isEmpty) return _defaultHold;
  final Map<String, Map<String, String>> holding = <String, Map<String, String>>{};
  for (final MapEntry<Object?, Object?> entry in parsed.map!.entries) {
    if (entry.key is! String || entry.value is! Map) return null;
    final Map<Object?, Object?> inner = entry.value! as Map<Object?, Object?>;
    holding[entry.key! as String] = <String, String>{
      for (final MapEntry<Object?, Object?> item in inner.entries)
        if (item.key is String && item.value is String) item.key! as String: item.value! as String,
    };
  }
  return holding;
}

bool _hasValidEffectiveDate(Transaction transaction) =>
    transaction.postings.any((Posting posting) => metaDate(posting.meta, 'effective_date') != null);

bool _hasMeaninglessEffectiveDate(Directive directive, Transaction transaction) {
  for (final Posting posting in transaction.postings) {
    final BeanDate? date = metaDate(posting.meta, 'effective_date');
    if (date != null && compareBeanDate(date, directive.date) == 0) return true;
  }
  return false;
}

Directive _withLink(Directive directive, Random random) {
  final Transaction transaction = transactionOf(directive)!;
  final String datePart = '${directive.date}'.replaceAll('-', '').substring(2);
  final String suffix = String.fromCharCodes(List<int>.generate(3, (int _) => 97 + random.nextInt(26)));
  return replaceTransaction(
    directive,
    transaction.copyWith(
      links: <Link>[
        ...transaction.links,
        Link(name: 'edate-$datePart-$suffix'),
      ],
    ),
  );
}

Posting _cleaned(Posting posting) => posting.copyWith(meta: metaWithout(posting.meta, 'effective_date'));

Directive _effectiveEntry(Directive original, BeanDate date, Posting hold, Posting originalPosting) {
  final Transaction transaction = transactionOf(original)!;
  return original.copyWith(
    date: date,
    meta: metaWith(original.meta, 'original_date', MetaValue.date(original.date)),
    body: DirectiveBody.transaction(transaction.copyWith(postings: <Posting>[hold, originalPosting])),
  );
}
