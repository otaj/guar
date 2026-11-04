// Turn plugin configuration fields into the literal string a ledger stores.

import 'package:guar_plugins/src/check_average_cost.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/currency_accounts.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/reds/daf_mirror.dart';
import 'package:guar_plugins/src/reds/zerosum.dart';

const PluginSetup averageCostSetup = PluginSetup(
  fields: <PluginField>[
    PluginNumberField(
      id: 'tolerance',
      label: 'Tolerance',
      hint: 'Default $checkAverageCostDefaultTolerance. One percent is 0.01.',
    ),
  ],
  decode: decodeAverageCost,
  encode: encodeAverageCost,
);

const PluginSetup commodityCheckSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'ignore',
      label: 'Ignored commodities',
      hint: 'An account pattern and a commodity pattern to skip.',
      columns: <String>['Account pattern', 'Commodity pattern'],
    ),
  ],
  decode: decodeCommodityCheck,
  encode: encodeCommodityCheck,
);

const PluginSetup commodityAttrSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'attributes',
      label: 'Attributes',
      hint: 'Leave allowed values empty to accept any value. Separate values with commas.',
      columns: <String>['Attribute', 'Allowed values'],
    ),
  ],
  decode: decodeCommodityAttr,
  encode: encodeCommodityAttr,
);

const PluginSetup currencyAccountsSetup = PluginSetup(
  fields: <PluginField>[
    PluginTextField(id: 'base', label: 'Base account', hint: 'Default $currencyAccountsDefaultBase.'),
  ],
  decode: decodeCurrencyAccounts,
  encode: encodeCurrencyAccounts,
);

const PluginSetup oneCommoditySetup = PluginSetup(
  fields: <PluginField>[
    PluginTextField(
      id: 'accounts',
      label: 'Account pattern',
      hint: 'Leave empty to check every account.',
    ),
  ],
  decode: decodeOneCommodity,
  encode: encodeOneCommodity,
);

const PluginSetup dafSetup = PluginSetup(
  fields: <PluginField>[
    PluginTextField(id: 'prefix', label: 'Account prefix', hint: 'Default $dafDefaultPrefix.'),
    PluginTextField(
      id: 'payee',
      label: 'Payee prefix',
      hint: 'Default is "Mirror " including the trailing space.',
    ),
  ],
  decode: decodeDaf,
  encode: encodeDaf,
);

const PluginSetup gainLossSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'rules',
      label: 'Rules',
      hint: 'A negative amount uses the third column. A positive amount uses the fourth.',
      columns: <String>['Account pattern', 'Text to replace', 'Negative amount', 'Positive amount'],
    ),
  ],
  decode: decodeGainLoss,
  encode: encodeGainLoss,
);

const PluginSetup longShortSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'rules',
      label: 'Rules',
      hint: 'Only the first rule is used. The third column is short-term and the fourth is long-term.',
      columns: <String>['Account pattern', 'Text to replace', 'Short-term', 'Long-term'],
    ),
  ],
  decode: decodeLongShort,
  encode: encodeLongShort,
);

const PluginSetup effectiveDateSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'holding',
      label: 'Holding accounts',
      hint: 'Leave empty to use the built-in Expenses and Income holding accounts.',
      columns: <String>['Account prefix', 'Earlier account', 'Later account'],
    ),
  ],
  decode: decodeEffectiveDate,
  encode: encodeEffectiveDate,
);

const PluginSetup opengroupSetup = PluginSetup(
  fields: <PluginField>[
    PluginRulesField(
      id: 'rules',
      label: 'Rules',
      hint: 'Leave empty to use the built-in rules. Rules you add replace those defaults.',
    ),
  ],
  decode: decodeOpengroup,
  encode: encodeOpengroup,
);

const PluginSetup renameAccountsSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'renames',
      label: 'Renames',
      hint: 'Each row is a regular expression and its replacement. Later rows see earlier replacements.',
      columns: <String>['Pattern', 'Replacement'],
    ),
  ],
  decode: decodeRenameAccounts,
  encode: encodeRenameAccounts,
);

const PluginSetup zerosumSetup = PluginSetup(
  fields: <PluginField>[
    PluginTableField(
      id: 'accounts',
      label: 'Zerosum accounts',
      hint: 'Account pattern, the account that receives a match, and how many days apart a pair may be.',
      columns: <String>['Account pattern', 'Target account', 'Days'],
    ),
    PluginTextField(id: 'replaceFrom', label: 'Text to replace'),
    PluginTextField(id: 'replaceTo', label: 'Replacement'),
    PluginNumberField(id: 'tolerance', label: 'Tolerance', hint: 'Default $zerosumDefaultTolerance.'),
    PluginFlagField(id: 'matchMetadata', label: 'Match metadata'),
    PluginTextField(
      id: 'matchMetadataName',
      label: 'Metadata name',
      hint: 'Default $zerosumDefaultMetadataName.',
    ),
    PluginFlagField(id: 'linkTransactions', label: 'Link transactions'),
    PluginTextField(id: 'linkPrefix', label: 'Link prefix', hint: 'Default $zerosumDefaultLinkPrefix.'),
    PluginFlagField(id: 'flagUnmatched', label: 'Flag unmatched'),
  ],
  decode: decodeZerosum,
  encode: encodeZerosum,
);

PluginStored decodeAverageCost(String? config) {
  if (config == null || config.trim().isEmpty) return const PluginStored();
  final ConfigLiteral parsed = parseConfigLiteral(config);
  final Object? value = parsed.value;
  if (parsed.error != null || value is! num) {
    return PluginStored.unparsed(config, parsed.error ?? 'Enter a number');
  }
  return PluginStored(text: <String, String>{'tolerance': _numberText(value)});
}

PluginWrite encodeAverageCost(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final String text = (stored.text['tolerance'] ?? '').trim();
  if (text.isEmpty) return const PluginWrite.ok(null);
  final String? number = _floatLiteral(text);
  if (number == null) return const PluginWrite.bad('Enter a number');
  return _finish(number);
}

PluginStored decodeCommodityCheck(String? config) => _decodeStringMap(config, 'ignore');

PluginWrite encodeCommodityCheck(PluginStored stored) => _encodeStringMap(stored, 'ignore');

PluginStored decodeCommodityAttr(String? config) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      final List<List<String>> rows = <List<String>>[];
      for (final MapEntry<Object?, Object?> entry in map.entries) {
        final Object? key = entry.key;
        if (key is! String) return PluginStored.unparsed(config!, 'Expected string keys');
        final Object? values = entry.value;
        if (values == null) {
          rows.add(<String>[key, '']);
          continue;
        }
        if (values is! List) return PluginStored.unparsed(config!, 'Expected a list of allowed values');
        final List<String> allowed = <String>[];
        for (final Object? item in values) {
          if (item is! String) return PluginStored.unparsed(config!, 'Expected string values');
          allowed.add(item);
        }
        rows.add(<String>[key, allowed.join(', ')]);
      }
      return PluginStored(tables: <String, List<List<String>>>{'attributes': rows});
  }
}

PluginWrite encodeCommodityAttr(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> map = <String, Object?>{};
  for (final List<String> row in _table(stored, 'attributes')) {
    final String name = _at(row, 0);
    final String allowed = _at(row, 1);
    if (name.isEmpty && allowed.isEmpty) continue;
    if (name.isEmpty) return const PluginWrite.bad('Enter an attribute name');
    if (allowed.isEmpty) {
      map[name] = null;
      continue;
    }
    map[name] = <Object?>[
      for (final String value in allowed.split(','))
        if (value.trim().isNotEmpty) value.trim(),
    ];
  }
  return _writeMap(map, emptyAsBraces: true);
}

PluginStored decodeCurrencyAccounts(String? config) {
  if (config == null || config.trim().isEmpty) return const PluginStored();
  return PluginStored(text: <String, String>{'base': config.trim()});
}

PluginWrite encodeCurrencyAccounts(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final String text = (stored.text['base'] ?? '').trim();
  if (text.isEmpty) return const PluginWrite.ok(null);
  if (!isCurrencyAccountsBase(text)) {
    return const PluginWrite.bad('Enter an account name, such as Equity:CurrencyAccounts');
  }
  return _finish(text);
}

PluginStored decodeOneCommodity(String? config) {
  if (config == null || config.trim().isEmpty) return const PluginStored();
  return PluginStored(text: <String, String>{'accounts': config});
}

PluginWrite encodeOneCommodity(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final String text = (stored.text['accounts'] ?? '').trim();
  if (text.isEmpty) return const PluginWrite.ok(null);
  try {
    RegExp(text);
  } on FormatException {
    return const PluginWrite.bad('That pattern is not a valid regular expression');
  }
  return _finish(text);
}

PluginStored decodeDaf(String? config) {
  if (config == null || config.trim().isEmpty) return const PluginStored();
  final String trimmed = config.trim();
  final ConfigLiteral parsed = parseConfigLiteral(trimmed);
  final Object? value = parsed.value;
  if (parsed.error != null || value == null) {
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return PluginStored.unparsed(config, parsed.error ?? 'Expected a dict configuration');
    }
    return PluginStored(text: <String, String>{'prefix': trimmed});
  }
  if (value is Map<Object?, Object?>) {
    if (value.keys.any((Object? key) => key is! String)) {
      return PluginStored.unparsed(config, 'Expected string keys');
    }
    return PluginStored(
      text: <String, String>{
        'prefix': value['account_prefix']?.toString() ?? '',
        'payee': value['payee_prefix']?.toString() ?? '',
      },
    );
  }
  return PluginStored(text: <String, String>{'prefix': value.toString().trim()});
}

PluginWrite encodeDaf(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final String prefix = (stored.text['prefix'] ?? '').trim();
  final String payee = stored.text['payee'] ?? '';
  final bool prefixDefault = prefix.isEmpty || prefix == dafDefaultPrefix;
  final bool payeeDefault = payee.isEmpty || payee == dafDefaultPayeePrefix;
  if (prefixDefault && payeeDefault) return const PluginWrite.ok(null);
  if (payeeDefault) return _finish(prefix.isEmpty ? dafDefaultPrefix : prefix);
  return _writeMap(<String, Object?>{
    'account_prefix': prefix.isEmpty ? dafDefaultPrefix : prefix,
    'payee_prefix': payee,
  });
}

PluginStored decodeGainLoss(String? config) => _decodeTuples(config, 'rules', 3);

PluginWrite encodeGainLoss(PluginStored stored) => _encodeTuples(stored, 'rules', 4);

PluginStored decodeLongShort(String? config) => _decodeTuples(config, 'rules', 3);

PluginWrite encodeLongShort(PluginStored stored) => _encodeTuples(stored, 'rules', 4);

PluginStored decodeEffectiveDate(String? config) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      final List<List<String>> rows = <List<String>>[];
      for (final MapEntry<Object?, Object?> entry in map.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;
        if (key is! String || value is! Map) {
          return PluginStored.unparsed(config!, 'Expected a dict of holding accounts');
        }
        final Map<Object?, Object?> inner = Map<Object?, Object?>.from(value);
        if (!inner.containsKey('earlier') || !inner.containsKey('later')) {
          return PluginStored.unparsed(config!, 'Each holding account needs earlier and later');
        }
        rows.add(<String>[key, inner['earlier'].toString(), inner['later'].toString()]);
      }
      return PluginStored(tables: <String, List<List<String>>>{'holding': rows});
  }
}

PluginWrite encodeEffectiveDate(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> map = <String, Object?>{};
  for (final List<String> row in _table(stored, 'holding')) {
    final String prefix = _at(row, 0);
    final String earlier = _at(row, 1);
    final String later = _at(row, 2);
    if (prefix.isEmpty && earlier.isEmpty && later.isEmpty) continue;
    if (prefix.isEmpty || earlier.isEmpty || later.isEmpty) {
      return const PluginWrite.bad('Fill in every column of the row.');
    }
    map[prefix] = <String, Object?>{'earlier': earlier, 'later': later};
  }
  return _writeMap(map);
}

PluginStored decodeOpengroup(String? config) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      final List<PluginRule> rules = <PluginRule>[];
      for (final MapEntry<Object?, Object?> entry in map.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;
        if (key is! String || value is! List || value.length < 2) {
          return PluginStored.unparsed(config!, 'Expected a rule name, a pattern, and inserts');
        }
        final Object? pattern = value[0];
        final Object? inserts = value[1];
        if (pattern is! String || inserts is! List) {
          return PluginStored.unparsed(config!, 'Expected a rule name, a pattern, and inserts');
        }
        final List<PluginInsert> pairs = <PluginInsert>[];
        for (final Object? item in inserts) {
          if (item is! List || item.length < 2 || item[0] is! String || item[1] is! String) {
            return PluginStored.unparsed(config!, 'Each insert needs an account and currencies');
          }
          pairs.add(PluginInsert(account: item[0] as String, currencies: item[1] as String));
        }
        rules.add(PluginRule(name: key, pattern: pattern, inserts: pairs));
      }
      return PluginStored(rules: <String, List<PluginRule>>{'rules': rules});
  }
}

PluginWrite encodeOpengroup(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> map = <String, Object?>{};
  for (final PluginRule rule in stored.rules['rules'] ?? const <PluginRule>[]) {
    final String name = rule.name.trim();
    final String pattern = rule.pattern.trim();
    final List<PluginInsert> inserts = <PluginInsert>[
      for (final PluginInsert insert in rule.inserts)
        if (insert.account.trim().isNotEmpty || insert.currencies.trim().isNotEmpty)
          PluginInsert(account: insert.account.trim(), currencies: insert.currencies.trim()),
    ];
    if (name.isEmpty && pattern.isEmpty && inserts.isEmpty) continue;
    if (name.isEmpty || pattern.isEmpty) return const PluginWrite.bad('Enter a rule name and a pattern');
    for (final PluginInsert insert in inserts) {
      if (insert.account.isEmpty || insert.currencies.isEmpty) {
        return const PluginWrite.bad('Each insert needs an account and currencies');
      }
    }
    map[name] = <Object?>[
      pattern,
      <Object?>[
        for (final PluginInsert insert in inserts) <Object?>[insert.account, insert.currencies],
      ],
    ];
  }
  return _writeMap(map);
}

PluginStored decodeRenameAccounts(String? config) => _decodeStringMap(config, 'renames');

PluginWrite encodeRenameAccounts(PluginStored stored) => _encodeStringMap(stored, 'renames');

PluginStored decodeZerosum(String? config) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      const Set<String> known = <String>{
        'account_name_replace',
        'flag_unmatched',
        'link_prefix',
        'link_transactions',
        'match_metadata',
        'match_metadata_name',
        'tolerance',
        'zerosum_accounts',
      };
      if (map.keys.any((Object? key) => key is! String || !known.contains(key))) {
        return PluginStored.unparsed(config!, 'Unrecognized zerosum configuration');
      }
      final List<List<String>> accounts = <List<String>>[];
      final Object? rawAccounts = map['zerosum_accounts'];
      if (rawAccounts != null) {
        if (rawAccounts is! Map) return PluginStored.unparsed(config!, 'Expected a dict of zerosum accounts');
        for (final MapEntry<Object?, Object?> entry in Map<Object?, Object?>.from(rawAccounts).entries) {
          final Object? spec = entry.value;
          if (entry.key is! String || spec is! List || spec.length < 2 || spec[1] is! num) {
            return PluginStored.unparsed(config!, 'Each zerosum account needs a target and a number of days');
          }
          accounts.add(<String>[entry.key! as String, spec[0]?.toString() ?? '', _numberText(spec[1] as num)]);
        }
      }
      final Object? replace = map['account_name_replace'];
      String replaceFrom = '';
      String replaceTo = '';
      if (replace != null) {
        if (replace is! List || replace.length < 2) {
          return PluginStored.unparsed(config!, 'account_name_replace needs two strings');
        }
        replaceFrom = replace[0]?.toString() ?? '';
        replaceTo = replace[1]?.toString() ?? '';
      }
      final Object? tolerance = map['tolerance'];
      if (tolerance != null && tolerance is! num) return PluginStored.unparsed(config!, 'Tolerance must be a number');
      return PluginStored(
        text: <String, String>{
          'replaceFrom': replaceFrom,
          'replaceTo': replaceTo,
          'tolerance': tolerance is num ? _numberText(tolerance) : '',
          'matchMetadataName': map['match_metadata_name']?.toString() ?? '',
          'linkPrefix': map['link_prefix']?.toString() ?? '',
        },
        flags: <String, bool>{
          'matchMetadata': map['match_metadata'] == true,
          'linkTransactions': map['link_transactions'] == true,
          'flagUnmatched': map['flag_unmatched'] == true,
        },
        tables: <String, List<List<String>>>{'accounts': accounts},
      );
  }
}

PluginWrite encodeZerosum(PluginStored stored) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> accounts = <String, Object?>{};
  for (final List<String> row in _table(stored, 'accounts')) {
    final String account = _at(row, 0);
    final String target = _at(row, 1);
    final String days = _at(row, 2);
    if (account.isEmpty && target.isEmpty && days.isEmpty) continue;
    if (account.isEmpty || days.isEmpty) {
      return const PluginWrite.bad('Enter an account pattern and a number of days');
    }
    final int? range = int.tryParse(days);
    if (range == null) return const PluginWrite.bad('Enter a whole number of days');
    accounts[account] = <Object?>[target, range];
  }
  final Map<String, Object?> map = <String, Object?>{};
  if (accounts.isNotEmpty) map['zerosum_accounts'] = accounts;
  final String replaceFrom = (stored.text['replaceFrom'] ?? '').trim();
  final String replaceTo = (stored.text['replaceTo'] ?? '').trim();
  if (replaceFrom.isNotEmpty || replaceTo.isNotEmpty) {
    map['account_name_replace'] = <Object?>[replaceFrom, replaceTo];
  }
  final String tolerance = (stored.text['tolerance'] ?? '').trim();
  if (tolerance.isNotEmpty) {
    final Object? number = _typedNumber(tolerance);
    if (number == null) return const PluginWrite.bad('Enter a number');
    map['tolerance'] = number;
  }
  if (stored.flags['matchMetadata'] ?? false) map['match_metadata'] = true;
  final String metadataName = (stored.text['matchMetadataName'] ?? '').trim();
  if (metadataName.isNotEmpty && metadataName != zerosumDefaultMetadataName) {
    map['match_metadata_name'] = metadataName;
  }
  if (stored.flags['linkTransactions'] ?? false) map['link_transactions'] = true;
  final String linkPrefix = (stored.text['linkPrefix'] ?? '').trim();
  if (linkPrefix.isNotEmpty && linkPrefix != zerosumDefaultLinkPrefix) map['link_prefix'] = linkPrefix;
  if (stored.flags['flagUnmatched'] ?? false) map['flag_unmatched'] = true;
  return _writeMap(map);
}

PluginStored _decodeStringMap(String? config, String field) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      final List<List<String>> rows = <List<String>>[];
      for (final MapEntry<Object?, Object?> entry in map.entries) {
        if (entry.key is! String || entry.value is! String) {
          return PluginStored.unparsed(config!, 'Expected a dict of strings');
        }
        rows.add(<String>[entry.key! as String, entry.value! as String]);
      }
      return PluginStored(tables: <String, List<List<String>>>{field: rows});
  }
}

PluginWrite _encodeStringMap(PluginStored stored, String field) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> map = <String, Object?>{};
  for (final List<String> row in _table(stored, field)) {
    final String key = _at(row, 0);
    final String value = _at(row, 1);
    if (key.isEmpty && value.isEmpty) continue;
    if (key.isEmpty || value.isEmpty) return const PluginWrite.bad('Fill in every column of the row.');
    map[key] = value;
  }
  return _writeMap(map);
}

PluginStored _decodeTuples(String? config, String field, int width) {
  final _Read read = _readDict(config);
  switch (read) {
    case _Empty():
      return const PluginStored();
    case _Failed(:final String message):
      return PluginStored.unparsed(config!, message);
    case _Dict(:final Map<Object?, Object?> map):
      final List<List<String>> rows = <List<String>>[];
      for (final MapEntry<Object?, Object?> entry in map.entries) {
        final Object? spec = entry.value;
        if (entry.key is! String || spec is! List || spec.length != width) {
          return PluginStored.unparsed(config!, 'Expected a dict of string lists');
        }
        final List<String> cells = <String>[entry.key! as String];
        for (final Object? item in spec) {
          if (item is! String) return PluginStored.unparsed(config!, 'Expected a dict of string lists');
          cells.add(item);
        }
        rows.add(cells);
      }
      return PluginStored(tables: <String, List<List<String>>>{field: rows});
  }
}

PluginWrite _encodeTuples(PluginStored stored, String field, int width) {
  if (stored.raw != null) return _finishRaw(stored.raw);
  final Map<String, Object?> map = <String, Object?>{};
  for (final List<String> row in _table(stored, field)) {
    final List<String> cells = <String>[for (int index = 0; index < width; index++) _at(row, index)];
    if (cells.every((String cell) => cell.isEmpty)) continue;
    if (cells.any((String cell) => cell.isEmpty)) {
      return const PluginWrite.bad('Fill in every column of the row.');
    }
    map[cells.first] = <Object?>[...cells.skip(1)];
  }
  return _writeMap(map);
}

sealed class _Read {
  const _Read();
}

class _Empty extends _Read {
  const _Empty();
}

class _Failed extends _Read {
  const _Failed(this.message);

  final String message;
}

class _Dict extends _Read {
  const _Dict(this.map);

  final Map<Object?, Object?> map;
}

_Read _readDict(String? config) {
  if (config == null || config.trim().isEmpty) return const _Empty();
  final ConfigLiteral parsed = parseConfigLiteral(config);
  if (parsed.error != null) return _Failed(parsed.error!);
  final Object? value = parsed.value;
  if (value is! Map<Object?, Object?>) return const _Failed('Expected a dict configuration');
  return _Dict(value);
}

List<List<String>> _table(PluginStored stored, String field) => stored.tables[field] ?? const <List<String>>[];

String _at(List<String> row, int index) => index < row.length ? row[index].trim() : '';

String _numberText(num value) {
  if (value is int) return '$value';
  return value.toString();
}

String? _floatLiteral(String text) {
  if (_typedNumber(text) == null) return null;
  if (text.contains('.') || text.contains('e') || text.contains('E')) return text;
  return '$text.0';
}

Object? _typedNumber(String text) {
  final double? value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  if (text.contains('.') || text.contains('e') || text.contains('E')) return value;
  return int.tryParse(text);
}

PluginWrite _writeMap(Map<String, Object?> map, {bool emptyAsBraces = false}) {
  if (map.isEmpty) return PluginWrite.ok(emptyAsBraces ? '{}' : null);
  return _finish(_pythonLiteral(map));
}

PluginWrite _finishRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const PluginWrite.ok(null);
  return _finish(raw);
}

PluginWrite _finish(String? config) {
  if (config == null) return const PluginWrite.ok(null);
  if (config.contains('"')) return const PluginWrite.bad(pluginQuoteError);
  if (config.contains('\n') || config.contains('\r')) return const PluginWrite.bad(pluginLineError);
  return PluginWrite.ok(config);
}

String _pythonLiteral(Object? value) {
  if (value == null) return 'None';
  if (value is bool) return value ? 'True' : 'False';
  if (value is int) return '$value';
  if (value is double) {
    final String text = value.toString();
    if (text.contains('.') || text.contains('e') || text.contains('E')) return text;
    return '$text.0';
  }
  if (value is String) return _pythonQuote(value);
  if (value is List<Object?>) return '[${value.map(_pythonLiteral).join(', ')}]';
  if (value is Map<String, Object?>) {
    final List<String> parts = <String>[
      for (final MapEntry<String, Object?> entry in value.entries)
        '${_pythonLiteral(entry.key)}: ${_pythonLiteral(entry.value)}',
    ];
    return '{${parts.join(', ')}}';
  }
  throw ArgumentError.value(value, 'value', 'Unsupported configuration value');
}

String _pythonQuote(String text) {
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return "'$escaped'";
}
