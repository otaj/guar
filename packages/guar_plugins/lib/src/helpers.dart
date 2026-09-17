// Shared helpers for stock plugins: sort keys, account use maps, hashing.

import 'package:guar_domain/guar_domain.dart';

int directiveTypeOrder(DirectiveBody body) => switch (body) {
  OpenBody() => -2,
  BalanceBody() => -1,
  DocumentBody() => 1,
  CloseBody() => 2,
  _ => 0,
};

int compareDirectiveDate(Directive a, Directive b) {
  final byDate = compareBeanDate(a.date, b.date);
  if (byDate != 0) return byDate;
  final byType = directiveTypeOrder(a.body).compareTo(directiveTypeOrder(b.body));
  if (byType != 0) return byType;
  return _originLine(a.origin).compareTo(_originLine(b.origin));
}

int _originLine(Origin origin) => switch (origin) {
  SourceOrigin(:final location) => location.linenoBegin,
  GeneratedOrigin() => 0,
};

BeanLocation nowhereLocation([String filename = '']) => BeanLocation(filename: filename, linenoBegin: 0, linenoEnd: 0);

BeanLocation directiveLocation(Directive directive, [String generatedFilename = '']) => switch (directive.origin) {
  SourceOrigin(:final location) => location,
  GeneratedOrigin() => nowhereLocation(generatedFilename),
};

String? metaText(MetaValue? value) => switch (value) {
  null => null,
  MetaText(:final value) => value,
  MetaAccount(:final value) => value.name,
  MetaCurrency(:final value) => value.name,
  MetaTag(:final value) => value.name,
  MetaDate(:final value) => '$value',
  MetaBoolean(:final value) => value ? 'TRUE' : 'FALSE',
  MetaNumber(:final value) => value.toString(),
  MetaAmount(:final value) => value.toString(),
};

Meta metaWithout(Meta meta, String key) => Meta(
  entries: [
    for (final entry in meta.entries)
      if (entry.key != key) entry,
  ],
);

bool isBalanceSheetAccount(Account account) => switch (account.type) {
  AccountType.assets || AccountType.liabilities || AccountType.equity => true,
  AccountType.income || AccountType.expenses => false,
};

Map<String, BeanDate> accountFirstUse(List<Directive> directives) {
  final first = <String, BeanDate>{};
  void consider(String account, BeanDate date) {
    final existing = first[account];
    if (existing == null || compareBeanDate(date, existing) < 0) {
      first[account] = date;
    }
  }

  for (final directive in directives) {
    final date = directive.date;
    switch (directive.body) {
      case OpenBody(:final account):
        consider(account.name, date);
      case CloseBody(:final account):
        consider(account.name, date);
      case BalanceBody(:final account):
        consider(account.name, date);
      case PadBody(:final account, :final sourceAccount):
        consider(account.name, date);
        consider(sourceAccount.name, date);
      case DocumentBody(:final account):
        consider(account.name, date);
      case NoteBody(:final account):
        consider(account.name, date);
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          consider(posting.account.name, date);
        }
      case CustomBody(:final values):
        for (final custom in values) {
          if (custom is CustomAccount) {
            consider(custom.value.name, date);
          }
        }
      case PriceBody() || CommodityBody() || EventBody() || QueryBody():
        break;
    }
  }
  return first;
}

Set<String> usedAccounts(List<Directive> directives) {
  final used = <String>{};
  for (final directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          used.add(posting.account.name);
        }
      case BalanceBody(:final account):
        used.add(account.name);
      case CloseBody(:final account):
        used.add(account.name);
      case PadBody(:final account, :final sourceAccount):
        used.add(account.name);
        used.add(sourceAccount.name);
      case DocumentBody(:final account):
        used.add(account.name);
      case NoteBody(:final account):
        used.add(account.name);
      default:
        break;
    }
  }
  return used;
}

Map<String, ({Directive? open, Directive? close})> accountOpenClose(List<Directive> directives) {
  final map = <String, ({Directive? open, Directive? close})>{};
  for (final directive in directives) {
    switch (directive.body) {
      case OpenBody(:final account):
        final existing = map[account.name];
        map[account.name] = (open: directive, close: existing?.close);
      case CloseBody(:final account):
        final existing = map[account.name];
        map[account.name] = (open: existing?.open, close: directive);
      default:
        break;
    }
  }
  return map;
}

Set<String> parentAccounts(Iterable<String> accounts) {
  final parents = <String>{};
  for (final account in accounts) {
    var name = account;
    while (true) {
      final colon = name.lastIndexOf(':');
      if (colon < 0) break;
      name = name.substring(0, colon);
      parents.add(name);
    }
  }
  return parents;
}

bool isStrictParentOf(String parent, String child) => child.startsWith('$parent:');

Account generatedAccount(String name, LedgerOptions options) => options.accountPrefixes.account(name);

String contentHash(Directive directive) {
  final buffer = StringBuffer()
    ..write(directive.date)
    ..write('|')
    ..write(directive.body.runtimeType)
    ..write('|')
    ..write(_bodyHash(directive.body));
  return buffer.toString();
}

String _bodyHash(DirectiveBody body) => switch (body) {
  OpenBody(:final account, :final currencies, :final booking) =>
    'open:${account.name}:${currencies.map((c) => c.name).join(',')}:$booking',
  CloseBody(:final account) => 'close:${account.name}',
  CommodityBody(:final currency) => 'commodity:${currency.name}',
  PadBody(:final account, :final sourceAccount) => 'pad:${account.name}:${sourceAccount.name}',
  BalanceBody(:final account, :final amount, :final tolerance) =>
    'balance:${account.name}:${amount.number}:${amount.currency.name}:$tolerance',
  PriceBody(:final currency, :final amount) => 'price:${currency.name}:${amount.number}:${amount.currency.name}',
  NoteBody(:final account, :final comment) => 'note:${account.name}:$comment',
  DocumentBody(:final account, :final filename) => 'document:${account.name}:$filename',
  EventBody(:final name, :final description) => 'event:$name:$description',
  QueryBody(:final name, :final queryString) => 'query:$name:$queryString',
  CustomBody(:final type, :final values) => 'custom:$type:${values.join(',')}',
  TransactionBody(:final value) =>
    'txn:${value.flag}:${value.payee}:${value.narration}:'
        '${value.tags.map((t) => t.name).join(',')}:'
        '${value.links.map((l) => l.name).join(',')}:'
        '${[for (final p in value.postings) _postingHash(p)].join(';')}',
};

String _postingHash(Posting posting) {
  final cost = posting.cost;
  final price = posting.price;
  return '${posting.flag}:${posting.account.name}:'
      '${posting.units.number} ${posting.units.currency.name}:'
      '${cost == null ? '' : '${cost.number} ${cost.currency.name} ${cost.date} ${cost.label}'}:'
      '${price == null ? '' : '${price.number} ${price.currency.name}'}';
}
