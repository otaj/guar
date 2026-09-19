// Shared helpers for beancount_reds_plugins ports: config, regex, opens, account rewrite.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult configError(List<Directive> directives, String message) =>
    (directives: directives, errors: <ProcessingError>[ProcessingError(message: message, location: nowhereLocation())]);

({Map<Object?, Object?>? map, String? error}) parseConfigMap(String? config) {
  if (config == null || config.trim().isEmpty) {
    return (map: const <Object?, Object?>{}, error: null);
  }
  final ConfigLiteral parsed = parseConfigLiteral(config);
  if (parsed.error != null) {
    return (map: null, error: parsed.error);
  }
  final Object? value = parsed.value;
  if (value is! Map<Object?, Object?>) {
    return (map: null, error: 'Expected a dict configuration');
  }
  return (map: value, error: null);
}

RegExp pythonRegExp(String pattern) {
  final String converted = pattern.replaceAllMapped(RegExp(r'\(\?P<([^>]+)>'), (Match match) => '(?<${match[1]}>');
  return RegExp(converted);
}

({String result, int count}) pythonSub(RegExp pattern, String replacement, String input) {
  int count = 0;
  final String result = input.replaceAllMapped(pattern, (Match match) {
    count++;
    return expandPythonReplacement(replacement, match);
  });
  return (result: result, count: count);
}

String expandPythonReplacement(String replacement, Match match) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < replacement.length; i++) {
    if (replacement[i] != r'\') {
      buffer.write(replacement[i]);
      continue;
    }
    if (i + 1 >= replacement.length) {
      buffer.write(r'\');
      break;
    }
    final String next = replacement[i + 1];
    if (next == r'\') {
      buffer.write(r'\');
      i++;
      continue;
    }
    if (next == 'g' && i + 2 < replacement.length && replacement[i + 2] == '<') {
      final int end = replacement.indexOf('>', i + 3);
      if (end < 0) {
        buffer.write(r'\');
        continue;
      }
      final String name = replacement.substring(i + 3, end);
      final int? index = int.tryParse(name);
      buffer.write(index != null ? (match.group(index) ?? '') : ((match as RegExpMatch).namedGroup(name) ?? ''));
      i = end;
      continue;
    }
    if (_isDigit(next)) {
      int j = i + 1;
      while (j < replacement.length && _isDigit(replacement[j])) {
        j++;
      }
      final int index = int.parse(replacement.substring(i + 1, j));
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
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (Match match) => values[match[1]] ?? match[0]!);

Account rewriteAccount(String name, LedgerOptions options) => generatedAccount(name, options);

BeanDate? parseIsoDate(Object? value) {
  if (value is BeanDate) return value;
  if (value is! String) return null;
  final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  return BeanDate(year: int.parse(match[1]!), month: int.parse(match[2]!), day: int.parse(match[3]!));
}

BeanDate? metaDate(Meta meta, String key) {
  final MetaValue? value = meta.lookup(key);
  return switch (value) {
    MetaDate(:final BeanDate value) => value,
    MetaText(:final String value) => parseIsoDate(value),
    _ => null,
  };
}

Meta metaWith(Meta meta, String key, MetaValue value) => Meta(
  entries: <MetaEntry>[
    for (final MetaEntry entry in meta.entries)
      if (entry.key != key) entry,
    MetaEntry(key: key, value: value),
  ],
);

bool metaFlag(Meta meta, String key) => switch (meta.lookup(key)) {
  MetaBoolean(:final bool value) => value,
  MetaText(:final String value) => value == 'TRUE' || value == 'true',
  _ => false,
};

List<Directive> createOpenDirectives(
  Iterable<String> newAccounts,
  List<Directive> entries,
  LedgerOptions options,
  ProcessingInfo info,
) {
  if (entries.isEmpty) return const <Directive>[];
  final Set<String> existing = <String>{
    for (final Directive directive in entries)
      if (directive.body case OpenBody(:final Account account)) account.name,
  };
  final BeanDate date = entries.first.date;
  final List<String> names = newAccounts.toSet().toList()..sort();
  return <Directive>[
    for (final String name in names)
      if (!existing.contains(name))
        Directive(
          origin: insertOrigin(
            date: date,
            body: DirectiveBody.open(account: generatedAccount(name, options)),
            existing: entries,
            info: info,
          ),
          date: date,
          body: DirectiveBody.open(account: generatedAccount(name, options)),
        ),
  ];
}

Directive rewriteDirectiveAccounts(Directive directive, String Function(String name) rename, LedgerOptions options) {
  Account mapAccount(Account account) {
    final String name = rename(account.name);
    if (name == account.name) return account;
    return generatedAccount(name, options);
  }

  Account mapBudgetAccount(Account account) {
    final String name = rename(account.name);
    if (name == account.name) return account;
    return options.accountPrefixes.budgetAccount(name);
  }

  switch (directive.body) {
    case TransactionBody(:final Transaction value):
      final List<Posting> postings = <Posting>[
        for (final Posting posting in value.postings) posting.copyWith(account: mapAccount(posting.account)),
      ];
      bool changed = false;
      for (int i = 0; i < postings.length; i++) {
        if (postings[i].account != value.postings[i].account) {
          changed = true;
          break;
        }
      }
      return changed
          ? directive.copyWith(body: DirectiveBody.transaction(value.copyWith(postings: postings)))
          : directive;
    case PadBody(:final Account account, :final Account sourceAccount):
      return directive.copyWith(
        body: DirectiveBody.pad(account: mapAccount(account), sourceAccount: mapAccount(sourceAccount)),
      );
    case OpenBody(:final Account account, :final List<Currency> currencies, :final BookingMethod? booking):
      return directive.copyWith(
        body: DirectiveBody.open(account: mapAccount(account), currencies: currencies, booking: booking),
      );
    case CloseBody(:final Account account):
      return directive.copyWith(body: DirectiveBody.close(account: mapAccount(account)));
    case BalanceBody(:final Account account, :final Amount amount, :final Decimal? tolerance):
      return directive.copyWith(
        body: DirectiveBody.balance(account: mapAccount(account), amount: amount, tolerance: tolerance),
      );
    case NoteBody(:final Account account, :final String comment, :final List<Tag> tags, :final List<Link> links):
      return directive.copyWith(
        body: DirectiveBody.note(account: mapAccount(account), comment: comment, tags: tags, links: links),
      );
    case DocumentBody(:final Account account, :final String filename, :final List<Tag> tags, :final List<Link> links):
      return directive.copyWith(
        body: DirectiveBody.document(account: mapAccount(account), filename: filename, tags: tags, links: links),
      );
    case CustomBody(:final String type, :final List<CustomValue> values):
      return directive.copyWith(
        body: DirectiveBody.custom(
          type: type,
          values: <CustomValue>[
            for (final CustomValue value in values)
              switch (value) {
                CustomAccount(:final Account value) => CustomValue.account(mapAccount(value)),
                _ => value,
              },
          ],
        ),
      );
    case BudgetBody(:final Account account, :final BudgetInterval interval, :final Amount amount):
      return directive.copyWith(
        body: DirectiveBody.budget(account: mapBudgetAccount(account), interval: interval, amount: amount),
      );
    case BudgetOffBody(:final Account account, :final Currency? currency):
      return directive.copyWith(
        body: DirectiveBody.budgetOff(account: mapBudgetAccount(account), currency: currency),
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
  final DateTime a = DateTime.utc(start.year, start.month, start.day);
  final DateTime b = DateTime.utc(end.year, end.month, end.day);
  return b.difference(a).inDays + 1;
}

bool isLongTermHolding(BeanDate acquired, BeanDate sold) =>
    compareBeanDate(sold, addDelta(acquired, const DateDelta(years: 1))) > 0;

Transaction? transactionOf(Directive directive) => switch (directive.body) {
  TransactionBody(:final Transaction value) => value,
  _ => null,
};

Directive replaceTransaction(Directive directive, Transaction transaction) =>
    directive.copyWith(body: DirectiveBody.transaction(transaction));
