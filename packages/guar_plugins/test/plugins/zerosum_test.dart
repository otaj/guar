// Port of beancount_reds_plugins.zerosum tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const _config =
    "{'zerosum_accounts': {"
    "'Assets:Zero-Sum-Accounts:Returns-and-Temporary': ('', 90), "
    "'Assets:Zero-Sum-Accounts:Checkings': ('', 90), "
    "'Assets:Zero-Sum-Accounts:Retirement': ('', 90)"
    "}, 'account_name_replace': ('Zero-Sum-Accounts', 'ZSA-Matched'), 'tolerance': 0.0098}";

const _plugin = 'plugin "beancount_reds_plugins.zerosum.zerosum" "$_config"\n';

void main() {
  test('empty entries', () {
    expect(booked('plugin "beancount_reds_plugins.zerosum.zerosum" "{}"\n'), isEmpty);
  });

  test('empty config leaves postings unchanged', () {
    final names = _matched(
      booked(
        'plugin "beancount_reds_plugins.zerosum.zerosum" "{}"\n'
        '2014-01-01 open Assets:Account1\n'
        '2014-01-01 open Income:Misc\n'
        '2014-01-15 *\n'
        '  Income:Misc          -1000 USD\n'
        '  Assets:Account1\n',
      ),
      ':ZSA-Matched',
    );
    expect(names, isEmpty);
  });

  test('matches a pair of zerosum refunds', () {
    final matched = _matchedTxns(_furniture(twoRefunds: true), ':ZSA-Matched');
    expect(matched, hasLength(3));
    expect(matched[0].postings[1].account.name, 'Assets:ZSA-Matched:Returns-and-Temporary');
    expect(matched[0].postings[2].account.name, 'Assets:ZSA-Matched:Returns-and-Temporary');
  });

  test('matches amounts above the configured posting size', () {
    expect(_matchedTxns(_trinket('0.014'), ':ZSA-Matched'), hasLength(2));
  });

  test('matches amounts below the configured posting size', () {
    expect(_matchedTxns(_trinket('0.004'), ':ZSA-Matched'), hasLength(2));
  });

  test('matches lookalike zero postings in one transaction', () {
    final matched = _matchedTxns(
      '$_plugin'
          '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
          '2020-06-01 * "Match two lookalike postings in one txn"\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary   0.00 USD\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary   0.00 USD\n',
      ':ZSA-Matched',
    );
    expect(matched, hasLength(1));
    expect(matched.single.postings.every((p) => p.account.name.contains('ZSA-Matched')), isTrue);
  });

  test('matches both postings in one transaction', () {
    final matched = _matchedTxns(
      '$_plugin'
          '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
          '2020-01-01 * "Match both postings in one txn"\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary  -1.00 USD\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary   1.00 USD\n',
      ':ZSA-Matched',
    );
    expect(matched, hasLength(1));
  });

  test('matches two same-sign postings that sum under tolerance', () {
    final matched = _matchedTxns(
      '$_plugin'
          '2015-01-01 open Liabilities:Credit-Cards:Green\n'
          '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
          '2021-01-01 * "under"\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary  -0.001 USD\n'
          '  Assets:Zero-Sum-Accounts:Returns-and-Temporary  -0.002 USD\n'
          '  Liabilities:Credit-Cards:Green\n',
      ':ZSA-Matched',
    );
    expect(matched, hasLength(1));
    expect(matched.single.postings.where((p) => p.account.name.contains('ZSA-Matched')), hasLength(2));
  });

  test('does not match two same-sign postings that sum above tolerance', () {
    expect(
      _matchedTxns(
        '$_plugin'
            '2015-01-01 open Liabilities:Credit-Cards:Green\n'
            '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
            '2021-01-01 * "over"\n'
            '  Assets:Zero-Sum-Accounts:Returns-and-Temporary  -0.00494 USD\n'
            '  Assets:Zero-Sum-Accounts:Returns-and-Temporary  -0.00496 USD\n'
            '  Liabilities:Credit-Cards:Green\n',
        ':ZSA-Matched',
      ),
      isEmpty,
    );
  });

  test('does not add match metadata by default', () {
    final matched = _matchedTxns(_furniture(twoRefunds: false), ':ZSA-Matched');
    expect(matched, hasLength(2));
    for (final txn in matched) {
      for (final posting in txn.postings) {
        expect(posting.meta.entries.any((e) => e.key == 'match_id'), isFalse);
      }
    }
  });

  test('adds matching metadata when configured', () {
    final matched = _payStub(matchMetadata: true);
    expect(matched, hasLength(3));
    expect(
      _meta(matched['Pay stub']!.postings[1], 'match_id'),
      _meta(matched['Bank account']!.postings[1], 'match_id'),
    );
    expect(
      _meta(matched['Pay stub']!.postings[2], 'match_id'),
      _meta(matched['401k statement']!.postings[1], 'match_id'),
    );
  });

  test('uses a custom metadata name', () {
    final matched = _payStub(matchMetadata: true, matchName: 'MATCH');
    expect(_meta(matched['Pay stub']!.postings[1], 'MATCH'), _meta(matched['Bank account']!.postings[1], 'MATCH'));
  });

  test('does not add links by default', () {
    for (final txn in _matchedTxns(_furniture(twoRefunds: false), ':ZSA-Matched')) {
      expect(txn.links.any((link) => link.name.startsWith('ZeroSum.')), isFalse);
    }
  });

  test('adds transaction links when configured', () {
    final matched = _payStub(linkTransactions: true);
    expect(_shareLink(matched['Pay stub']!, matched['Bank account']!, 'ZeroSum.'), isTrue);
    expect(_shareLink(matched['Pay stub']!, matched['401k statement']!, 'ZeroSum.'), isTrue);
    expect(_shareLink(matched['Bank account']!, matched['401k statement']!, 'ZeroSum.'), isFalse);
  });

  test('uses a custom link prefix', () {
    final matched = _payStub(linkTransactions: true, linkPrefix: 'ZSM');
    expect(_shareLink(matched['Pay stub']!, matched['Bank account']!, 'ZSM'), isTrue);
  });
}

List<String> _matched(List<Directive> directives, String pattern) => [
  for (final txn in _matchedTxns(directives, pattern))
    for (final posting in txn.postings)
      if (posting.account.name.contains(pattern.substring(1))) posting.account.name,
];

List<Transaction> _matchedTxns(Object source, String pattern) {
  final directives = source is String ? booked(source) : source as List<Directive>;
  return [
    for (final directive in directives)
      if (directive.body case TransactionBody(
        :final value,
      ) when value.postings.any((p) => p.account.name.contains(pattern.substring(1))))
        value,
  ];
}

String _furniture({required bool twoRefunds}) =>
    '$_plugin'
    '2015-01-01 open Liabilities:Credit-Cards:Green\n'
    '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
    '2015-06-15 * "Expensive furniture"\n'
    '  Liabilities:Credit-Cards:Green                         -2526.02 USD\n'
    '  Assets:Zero-Sum-Accounts:Returns-and-Temporary          1263.01 USD\n'
    '  Assets:Zero-Sum-Accounts:Returns-and-Temporary          1263.01 USD\n'
    '2015-06-23 * "Expensive furniture Refund"\n'
    '  Liabilities:Credit-Cards:Green                          1263.01 USD\n'
    '  Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
    '${twoRefunds ? '2015-06-23 * "Expensive furniture Refund 2"\n'
              '  Liabilities:Credit-Cards:Green                          1263.01 USD\n'
              '  Assets:Zero-Sum-Accounts:Returns-and-Temporary\n' : ''}';

String _trinket(String amount) =>
    '$_plugin'
    '2015-01-01 open Liabilities:Credit-Cards:Green\n'
    '2015-01-01 open Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
    '2015-06-15 * "Trinket"\n'
    '  Liabilities:Credit-Cards:Green                         -$amount USD\n'
    '  Assets:Zero-Sum-Accounts:Returns-and-Temporary\n'
    '2015-06-23 * "Trinket refund"\n'
    '  Liabilities:Credit-Cards:Green                          $amount USD\n'
    '  Assets:Zero-Sum-Accounts:Returns-and-Temporary\n';

Map<String, Transaction> _payStub({
  bool matchMetadata = false,
  String? matchName,
  bool linkTransactions = false,
  String? linkPrefix,
}) {
  final extra = [
    if (matchMetadata) "'match_metadata': True",
    if (matchName != null) "'match_metadata_name': '$matchName'",
    if (linkTransactions) "'link_transactions': True",
    if (linkPrefix != null) "'link_prefix': '$linkPrefix'",
  ].join(', ');
  final config = extra.isEmpty ? _config : '${_config.substring(0, _config.length - 1)}, $extra}';
  final directives = booked(
    'plugin "beancount_reds_plugins.zerosum.zerosum" "$config"\n'
    '2023-01-01 open Income:Salary\n'
    '2023-01-01 open Assets:Bank:Checkings\n'
    '2023-01-01 open Assets:Zero-Sum-Accounts:Checkings\n'
    '2023-01-01 open Assets:Brokerage:Retirement\n'
    '2023-01-01 open Assets:Zero-Sum-Accounts:Retirement\n'
    '2024-02-15 * "Pay stub"\n'
    '  Income:Salary                               -1100.06 USD\n'
    '  Assets:Zero-Sum-Accounts:Checkings            999.47 USD\n'
    '  Assets:Zero-Sum-Accounts:Retirement           100.59 USD\n'
    '2024-02-16 * "Bank account"\n'
    '  Assets:Bank:Checkings                         999.47 USD\n'
    '  Assets:Zero-Sum-Accounts:Checkings\n'
    '2024-02-16 * "401k statement"\n'
    '  Assets:Brokerage:Retirement                   100.59 USD\n'
    '  Assets:Zero-Sum-Accounts:Retirement\n',
  );
  return {for (final txn in _matchedTxns(directives, ':ZSA-Matched')) txn.narration: txn};
}

String? _meta(Posting posting, String key) {
  for (final entry in posting.meta.entries) {
    if (entry.key == key) {
      return switch (entry.value) {
        MetaText(:final value) => value,
        _ => entry.value?.toString(),
      };
    }
  }
  return null;
}

bool _shareLink(Transaction left, Transaction right, String prefix) {
  final names = left.links.map((l) => l.name).toSet().intersection(right.links.map((l) => l.name).toSet());
  return names.any((name) => name.startsWith(prefix));
}
