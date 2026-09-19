// Shared helpers for stock plugins: sort keys and account use maps.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

int directiveTypeOrder(DirectiveBody body) => switch (body) {
  OpenBody() => -2,
  BalanceBody() => -1,
  DocumentBody() => 1,
  CloseBody() => 2,
  _ => 0,
};

int compareDirectiveDate(Directive a, Directive b) {
  final int byDate = compareBeanDate(a.date, b.date);
  if (byDate != 0) return byDate;
  final int byType = directiveTypeOrder(a.body).compareTo(directiveTypeOrder(b.body));
  if (byType != 0) return byType;
  return _originLine(a.origin).compareTo(_originLine(b.origin));
}

int _originLine(Origin origin) => switch (origin) {
  SourceOrigin(:final BeanLocation location) => location.linenoBegin,
  GeneratedOrigin() => 0,
};

BeanLocation nowhereLocation([String filename = '']) => BeanLocation(filename: filename, linenoBegin: 0, linenoEnd: 0);

BeanLocation directiveLocation(Directive directive, [String generatedFilename = '']) => switch (directive.origin) {
  SourceOrigin(:final BeanLocation location) => location,
  GeneratedOrigin() => nowhereLocation(generatedFilename),
};

String? metaText(MetaValue? value) => switch (value) {
  null => null,
  MetaText(:final String value) => value,
  MetaAccount(:final Account value) => value.name,
  MetaCurrency(:final Currency value) => value.name,
  MetaTag(:final Tag value) => value.name,
  MetaDate(:final BeanDate value) => '$value',
  MetaBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
  MetaNumber(:final Decimal value) => value.toString(),
  MetaAmount(:final Amount value) => value.toString(),
};

Meta metaWithout(Meta meta, String key) => Meta(
  entries: <MetaEntry>[
    for (final MetaEntry entry in meta.entries)
      if (entry.key != key) entry,
  ],
);

bool isBalanceSheetAccount(Account account) => switch (account.type) {
  AccountType.assets || AccountType.liabilities || AccountType.equity => true,
  AccountType.income || AccountType.expenses => false,
};

Map<String, BeanDate> accountFirstUse(List<Directive> directives) {
  final Map<String, BeanDate> first = <String, BeanDate>{};
  void consider(String account, BeanDate date) {
    final BeanDate? existing = first[account];
    if (existing == null || compareBeanDate(date, existing) < 0) {
      first[account] = date;
    }
  }

  for (final Directive directive in directives) {
    final BeanDate date = directive.date;
    switch (directive.body) {
      case OpenBody(:final Account account):
        consider(account.name, date);
      case CloseBody(:final Account account):
        consider(account.name, date);
      case BalanceBody(:final Account account):
        consider(account.name, date);
      case PadBody(:final Account account, :final Account sourceAccount):
        consider(account.name, date);
        consider(sourceAccount.name, date);
      case DocumentBody(:final Account account):
        consider(account.name, date);
      case NoteBody(:final Account account):
        consider(account.name, date);
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          consider(posting.account.name, date);
        }
      case CustomBody(:final List<CustomValue> values):
        for (final CustomValue custom in values) {
          if (custom is CustomAccount) {
            consider(custom.value.name, date);
          }
        }
      case BudgetBody(:final Account account) || BudgetOffBody(:final Account account):
        consider(account.name, date);
      case PriceBody() || CommodityBody() || EventBody() || QueryBody():
        break;
    }
  }
  return first;
}

Set<String> usedAccounts(List<Directive> directives) {
  final Set<String> used = <String>{};
  for (final Directive directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          used.add(posting.account.name);
        }
      case BalanceBody(:final Account account):
        used.add(account.name);
      case CloseBody(:final Account account):
        used.add(account.name);
      case PadBody(:final Account account, :final Account sourceAccount):
        used.add(account.name);
        used.add(sourceAccount.name);
      case DocumentBody(:final Account account):
        used.add(account.name);
      case NoteBody(:final Account account):
        used.add(account.name);
      default:
        break;
    }
  }
  return used;
}

Map<String, ({Directive? open, Directive? close})> accountOpenClose(List<Directive> directives) {
  final Map<String, ({Directive? close, Directive? open})> map = <String, ({Directive? open, Directive? close})>{};
  for (final Directive directive in directives) {
    switch (directive.body) {
      case OpenBody(:final Account account):
        final ({Directive? close, Directive? open})? existing = map[account.name];
        map[account.name] = (open: directive, close: existing?.close);
      case CloseBody(:final Account account):
        final ({Directive? close, Directive? open})? existing = map[account.name];
        map[account.name] = (open: existing?.open, close: directive);
      default:
        break;
    }
  }
  return map;
}

Set<String> parentAccounts(Iterable<String> accounts) {
  final Set<String> parents = <String>{};
  for (final String account in accounts) {
    String name = account;
    while (true) {
      final int colon = name.lastIndexOf(':');
      if (colon < 0) break;
      name = name.substring(0, colon);
      parents.add(name);
    }
  }
  return parents;
}

Account generatedAccount(String name, LedgerOptions options) => options.accountPrefixes.account(name);
