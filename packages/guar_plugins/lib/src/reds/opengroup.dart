// Insert open/close sets from opengroup_* metadata on parent accounts.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/common.dart';

const String _accountPattern = '(?P<root>[^:]*):(?P<subroot>[^:]*):(?P<taxability>[^:]*):(?P<account_name>.*)';

final Map<String, ({String pattern, List<(String account, String currencies)> inserts})> _defaultRules =
    <String, ({List<(String, String)> inserts, String pattern})>{
      'cash_and_fees': (
        pattern: _accountPattern,
        inserts: <(String, String)>[
          ('{f_acct}:{f_ticker}', '{f_opcurr}'),
          ('Expenses:Fees-and-Charges:Brokerage-Fees:{taxability}:{account_name}', '{f_opcurr}'),
        ],
      ),
      'commodity_leaves_income': (
        pattern: _accountPattern,
        inserts: <(String, String)>[
          ('Income:{subroot}:{taxability}:Dividends:{account_name}:{f_ticker}', '{f_opcurr}'),
          ('Income:{subroot}:{taxability}:Interest:{account_name}:{f_ticker}', '{f_opcurr}'),
          ('Income:{subroot}:{taxability}:Capital-Gains:{account_name}:{f_ticker}', '{f_opcurr}'),
        ],
      ),
      'commodity_leaves_income_and_asset': (
        pattern: _accountPattern,
        inserts: <(String, String)>[
          ('{f_acct}:{f_ticker}', '{f_ticker}'),
          ('Income:{subroot}:{taxability}:Dividends:{account_name}:{f_ticker}', '{f_opcurr}'),
          ('Income:{subroot}:{taxability}:Interest:{account_name}:{f_ticker}', '{f_opcurr}'),
          ('Income:{subroot}:{taxability}:Capital-Gains:{account_name}:{f_ticker}', '{f_opcurr}'),
        ],
      ),
      'commodity_leaves_cgdists': (
        pattern: _accountPattern,
        inserts: <(String, String)>[
          ('Income:{subroot}:{taxability}:Capital-Gains-Distributions:Long:{account_name}:{f_ticker}', '{f_opcurr}'),
          ('Income:{subroot}:{taxability}:Capital-Gains-Distributions:Short:{account_name}:{f_ticker}', '{f_opcurr}'),
        ],
      ),
    };

BookPluginResult opengroup(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
  final ({String? error, Map<Object?, Object?>? map}) parsed = parseConfigMap(config);
  if (parsed.error != null) {
    return configError(directives, 'Invalid configuration for opengroup plugin; skipping.');
  }
  final Map<String, ({List<(String, String)> inserts, String pattern})>? rules = parsed.map!.isEmpty
      ? _defaultRules
      : _parseRules(parsed.map!);
  if (rules == null) {
    return configError(directives, 'Invalid configuration for opengroup plugin; skipping.');
  }
  final String opCurrency = options.operatingCurrency.isNotEmpty ? options.operatingCurrency.first.name : 'USD';
  final List<Directive> inserted = <Directive>[];
  for (final Directive directive in directives) {
    final String? account = switch (directive.body) {
      OpenBody(:final Account account) || CloseBody(:final Account account) => account.name,
      _ => null,
    };
    if (account == null) continue;
    for (final MetaEntry entry in directive.meta.entries) {
      final bool open = entry.key.startsWith('opengroup_');
      final bool close = entry.key.startsWith('closegroup_');
      if (!open && !close) continue;
      final String ruleName = entry.key.split('_').skip(1).join('_');
      final List<String> leaves = switch (entry.value) {
        MetaText(:final String value) => value.split(','),
        _ => const <String>[],
      };
      for (final String leaf in leaves) {
        for (final ({String account, List<String> currencies}) acc in _runRule(
          rules,
          ruleName,
          account,
          leaf.trim(),
          opCurrency,
        )) {
          if (open) {
            final DirectiveBody body = DirectiveBody.open(
              account: rewriteAccount(acc.account, options),
              currencies: <Currency>[for (final String currency in acc.currencies) Currency(name: currency)],
            );
            inserted.add(
              Directive(
                origin: insertOrigin(date: directive.date, body: body, existing: directives, info: info),
                date: directive.date,
                body: body,
              ),
            );
          } else {
            final DirectiveBody body = DirectiveBody.close(account: rewriteAccount(acc.account, options));
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
  return (directives: <Directive>[...directives, ...inserted], errors: const <ProcessingError>[]);
}

Map<String, ({String pattern, List<(String account, String currencies)> inserts})>? _parseRules(
  Map<Object?, Object?> config,
) {
  final Map<String, ({List<(String, String)> inserts, String pattern})> rules =
      <String, ({String pattern, List<(String account, String currencies)> inserts})>{};
  for (final MapEntry<Object?, Object?> entry in config.entries) {
    if (entry.key is! String || entry.value is! List) return null;
    final List<Object?> spec = entry.value! as List<Object?>;
    if (spec.length < 2 || spec[0] is! String || spec[1] is! List) return null;
    final List<(String, String)> inserts = <(String, String)>[];
    for (final Object? item in spec[1]! as List<Object?>) {
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
  final ({List<(String, String)> inserts, String pattern})? rule = rules[ruleName];
  if (rule == null) return const <({String account, List<String> currencies})>[];
  final RegExpMatch? match = pythonRegExp(rule.pattern).firstMatch(account);
  if (match == null) return const <({String account, List<String> currencies})>[];
  final Map<String, String> values = <String, String>{
    'f_acct': account,
    'f_ticker': ticker,
    'f_opcurr': opCurrency,
    for (final String name in match.groupNames) name: match.namedGroup(name) ?? '',
  };
  return <({String account, List<String> currencies})>[
    for (final (String, String) insert in rule.inserts)
      (account: formatMap(insert.$1, values), currencies: formatMap(insert.$2, values).split(',')),
  ];
}
