// Shared helpers for beancount_reds_plugins ports: config, regex, opens, account rewrite.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import '../config_literal.dart';
import '../helpers.dart';

BookPluginResult configError(List<Directive> directives, String message) =>
    (directives: directives, errors: [ProcessingError(message: message, location: nowhereLocation())]);

({Map<Object?, Object?>? map, String? error}) parseConfigMap(String? config) {
  if (config == null || config.trim().isEmpty) {
    return (map: const {}, error: null);
  }
  final parsed = parseConfigLiteral(config);
  if (parsed.error != null) {
    return (map: null, error: parsed.error);
  }
  final value = parsed.value;
  if (value is! Map<Object?, Object?>) {
    return (map: null, error: 'Expected a dict configuration');
  }
  return (map: value, error: null);
}

RegExp pythonRegExp(String pattern) {
  final converted = pattern.replaceAllMapped(RegExp(r'\(\?P<([^>]+)>'), (match) => '(?<${match[1]}>');
  return RegExp(converted);
}

({String result, int count}) pythonSub(RegExp pattern, String replacement, String input) {
  var count = 0;
  final result = input.replaceAllMapped(pattern, (match) {
    count++;
    return expandPythonReplacement(replacement, match);
  });
  return (result: result, count: count);
}

String expandPythonReplacement(String replacement, Match match) {
  final buffer = StringBuffer();
  for (var i = 0; i < replacement.length; i++) {
    if (replacement[i] != r'\') {
      buffer.write(replacement[i]);
      continue;
    }
    if (i + 1 >= replacement.length) {
      buffer.write(r'\');
      break;
    }
    final next = replacement[i + 1];
    if (next == r'\') {
      buffer.write(r'\');
      i++;
      continue;
    }
    if (next == 'g' && i + 2 < replacement.length && replacement[i + 2] == '<') {
      final end = replacement.indexOf('>', i + 3);
      if (end < 0) {
        buffer.write(r'\');
        continue;
      }
      final name = replacement.substring(i + 3, end);
      final index = int.tryParse(name);
      buffer.write(index != null ? (match.group(index) ?? '') : ((match as RegExpMatch).namedGroup(name) ?? ''));
      i = end;
      continue;
    }
    if (_isDigit(next)) {
      var j = i + 1;
      while (j < replacement.length && _isDigit(replacement[j])) {
        j++;
      }
      final index = int.parse(replacement.substring(i + 1, j));
      buffer.write(match.group(index) ?? '');
      i = j - 1;
      continue;
    }
    buffer.write(next);
    i++;
  }
  return buffer.toString();
}

bool _isDigit(String char) => char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

String formatMap(String template, Map<String, String> values) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) => values[match[1]] ?? match[0]!);

Account rewriteAccount(String name, LedgerOptions options) => generatedAccount(name, options);

BeanDate? parseIsoDate(Object? value) {
  if (value is BeanDate) return value;
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  return BeanDate(year: int.parse(match[1]!), month: int.parse(match[2]!), day: int.parse(match[3]!));
}

BeanDate? metaDate(Meta meta, String key) {
  final value = meta.lookup(key);
  return switch (value) {
    MetaDate(:final value) => value,
    MetaText(:final value) => parseIsoDate(value),
    _ => null,
  };
}

Meta metaWith(Meta meta, String key, MetaValue value) => Meta(
  entries: [
    for (final entry in meta.entries)
      if (entry.key != key) entry,
    MetaEntry(key: key, value: value),
  ],
);

bool metaFlag(Meta meta, String key) => switch (meta.lookup(key)) {
  MetaBoolean(:final value) => value,
  MetaText(:final value) => value == 'TRUE' || value == 'true',
  _ => false,
};

List<Directive> createOpenDirectives(Iterable<String> newAccounts, List<Directive> entries, LedgerOptions options) {
  if (entries.isEmpty) return const [];
  final existing = {
    for (final directive in entries)
      if (directive.body case OpenBody(:final account)) account.name,
  };
  final date = entries.first.date;
  final names = newAccounts.toSet().toList()..sort();
  return [
    for (final name in names)
      if (!existing.contains(name))
        Directive(
          origin: const Origin.generated(),
          date: date,
          body: DirectiveBody.open(account: generatedAccount(name, options)),
        ),
  ];
}

Directive rewriteDirectiveAccounts(Directive directive, String Function(String name) rename, LedgerOptions options) {
  Account mapAccount(Account account) {
    final name = rename(account.name);
    if (name == account.name) return account;
    return generatedAccount(name, options);
  }

  switch (directive.body) {
    case TransactionBody(:final value):
      final postings = [for (final posting in value.postings) posting.copyWith(account: mapAccount(posting.account))];
      var changed = false;
      for (var i = 0; i < postings.length; i++) {
        if (postings[i].account != value.postings[i].account) {
          changed = true;
          break;
        }
      }
      return changed
          ? directive.copyWith(body: DirectiveBody.transaction(value.copyWith(postings: postings)))
          : directive;
    case PadBody(:final account, :final sourceAccount):
      return directive.copyWith(
        body: DirectiveBody.pad(account: mapAccount(account), sourceAccount: mapAccount(sourceAccount)),
      );
    case OpenBody(:final account, :final currencies, :final booking):
      return directive.copyWith(
        body: DirectiveBody.open(account: mapAccount(account), currencies: currencies, booking: booking),
      );
    case CloseBody(:final account):
      return directive.copyWith(body: DirectiveBody.close(account: mapAccount(account)));
    case BalanceBody(:final account, :final amount, :final tolerance):
      return directive.copyWith(
        body: DirectiveBody.balance(account: mapAccount(account), amount: amount, tolerance: tolerance),
      );
    case NoteBody(:final account, :final comment, :final tags, :final links):
      return directive.copyWith(
        body: DirectiveBody.note(account: mapAccount(account), comment: comment, tags: tags, links: links),
      );
    case DocumentBody(:final account, :final filename, :final tags, :final links):
      return directive.copyWith(
        body: DirectiveBody.document(account: mapAccount(account), filename: filename, tags: tags, links: links),
      );
    case CustomBody(:final type, :final values):
      return directive.copyWith(
        body: DirectiveBody.custom(
          type: type,
          values: [
            for (final value in values)
              switch (value) {
                CustomAccount(:final value) => CustomValue.account(mapAccount(value)),
                _ => value,
              },
          ],
        ),
      );
    case PriceBody() || CommodityBody() || EventBody() || QueryBody():
      return directive;
  }
}

Decimal toDecimal(Object? value) {
  if (value is Decimal) return value;
  if (value is int) return Decimal.fromInt(value);
  if (value is num) return Decimal.parse(value.toString());
  if (value is String) return Decimal.parse(value);
  throw FormatException('Expected a number, got $value');
}

int daysInclusive(BeanDate start, BeanDate end) {
  final a = DateTime.utc(start.year, start.month, start.day);
  final b = DateTime.utc(end.year, end.month, end.day);
  return b.difference(a).inDays + 1;
}

bool isLongTermHolding(BeanDate acquired, BeanDate sold) =>
    compareBeanDate(sold, addDelta(acquired, const DateDelta(years: 1))) > 0;

Transaction? transactionOf(Directive directive) => switch (directive.body) {
  TransactionBody(:final value) => value,
  _ => null,
};

Directive replaceTransaction(Directive directive, Transaction transaction) =>
    directive.copyWith(body: DirectiveBody.transaction(transaction));
