// Insert open/close sets from opengroup_* metadata on parent accounts.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'common.dart';

const _accountPattern = r'(?P<root>[^:]*):(?P<subroot>[^:]*):(?P<taxability>[^:]*):(?P<account_name>.*)';

final Map<String, ({String pattern, List<(String account, String currencies)> inserts})> _defaultRules = {
  'cash_and_fees': (
    pattern: _accountPattern,
    inserts: [
      ('{f_acct}:{f_ticker}', '{f_opcurr}'),
      ('Expenses:Fees-and-Charges:Brokerage-Fees:{taxability}:{account_name}', '{f_opcurr}'),
    ],
  ),
  'commodity_leaves_income': (
    pattern: _accountPattern,
    inserts: [
      ('Income:{subroot}:{taxability}:Dividends:{account_name}:{f_ticker}', '{f_opcurr}'),
      ('Income:{subroot}:{taxability}:Interest:{account_name}:{f_ticker}', '{f_opcurr}'),
      ('Income:{subroot}:{taxability}:Capital-Gains:{account_name}:{f_ticker}', '{f_opcurr}'),
    ],
  ),
  'commodity_leaves_income_and_asset': (
    pattern: _accountPattern,
    inserts: [
      ('{f_acct}:{f_ticker}', '{f_ticker}'),
      ('Income:{subroot}:{taxability}:Dividends:{account_name}:{f_ticker}', '{f_opcurr}'),
      ('Income:{subroot}:{taxability}:Interest:{account_name}:{f_ticker}', '{f_opcurr}'),
      ('Income:{subroot}:{taxability}:Capital-Gains:{account_name}:{f_ticker}', '{f_opcurr}'),
    ],
  ),
  'commodity_leaves_cgdists': (
    pattern: _accountPattern,
    inserts: [
      ('Income:{subroot}:{taxability}:Capital-Gains-Distributions:Long:{account_name}:{f_ticker}', '{f_opcurr}'),
      ('Income:{subroot}:{taxability}:Capital-Gains-Distributions:Short:{account_name}:{f_ticker}', '{f_opcurr}'),
    ],
  ),
};

BookPluginResult opengroup(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for opengroup plugin; skipping.');
  }
  final rules = parsed.map!.isEmpty ? _defaultRules : _parseRules(parsed.map!);
  if (rules == null) {
    return configError(directives, 'Invalid configuration for opengroup plugin; skipping.');
  }
  final opCurrency = options.operatingCurrency.isNotEmpty ? options.operatingCurrency.first.name : 'USD';
  final inserted = <Directive>[];
  for (final directive in directives) {
    final account = switch (directive.body) {
      OpenBody(:final account) || CloseBody(:final account) => account.name,
      _ => null,
    };
    if (account == null) continue;
    for (final entry in directive.meta.entries) {
      final open = entry.key.startsWith('opengroup_');
      final close = entry.key.startsWith('closegroup_');
      if (!open && !close) continue;
      final ruleName = entry.key.split('_').skip(1).join('_');
      final leaves = switch (entry.value) {
        MetaText(:final value) => value.split(','),
        _ => const <String>[],
      };
      for (final leaf in leaves) {
        for (final acc in _runRule(rules, ruleName, account, leaf.trim(), opCurrency)) {
          if (open) {
            final body = DirectiveBody.open(
              account: rewriteAccount(acc.account, options),
              currencies: [for (final currency in acc.currencies) Currency(name: currency)],
            );
            inserted.add(
              Directive(
                origin: insertOrigin(date: directive.date, body: body, existing: directives, info: info),
                date: directive.date,
                body: body,
              ),
            );
          } else {
            final body = DirectiveBody.close(account: rewriteAccount(acc.account, options));
            inserted.add(
              Directive(
                origin: insertOrigin(date: directive.date, body: body, existing: directives, info: info),
                date: directive.date,
                body: body,
              ),
            );
          }
        }
      }
    }
  }
  return (directives: [...directives, ...inserted], errors: const []);
}

Map<String, ({String pattern, List<(String account, String currencies)> inserts})>? _parseRules(
  Map<Object?, Object?> config,
) {
  final rules = <String, ({String pattern, List<(String account, String currencies)> inserts})>{};
  for (final entry in config.entries) {
    if (entry.key is! String || entry.value is! List) return null;
    final spec = entry.value! as List<Object?>;
    if (spec.length < 2 || spec[0] is! String || spec[1] is! List) return null;
    final inserts = <(String, String)>[];
    for (final item in spec[1]! as List<Object?>) {
      if (item is! List || item.length < 2 || item[0] is! String || item[1] is! String) return null;
      inserts.add((item[0]! as String, item[1]! as String));
    }
    rules[entry.key! as String] = (pattern: spec[0]! as String, inserts: inserts);
  }
  return rules;
}

List<({String account, List<String> currencies})> _runRule(
  Map<String, ({String pattern, List<(String account, String currencies)> inserts})> rules,
  String ruleName,
  String account,
  String ticker,
  String opCurrency,
) {
  final rule = rules[ruleName];
  if (rule == null) return const [];
  final match = pythonRegExp(rule.pattern).firstMatch(account);
  if (match == null) return const [];
  final values = {
    'f_acct': account,
    'f_ticker': ticker,
    'f_opcurr': opCurrency,
    for (final name in match.groupNames) name: match.namedGroup(name) ?? '',
  };
  return [
    for (final insert in rule.inserts)
      (account: formatMap(insert.$1, values), currencies: formatMap(insert.$2, values).split(',')),
  ];
}
