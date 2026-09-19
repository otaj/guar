// Query-time OPEN / CLOSE / CLEAR and clamp_opt date-window summarization.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'package:guar_query/src/ast.dart';
import 'package:guar_query/src/convert.dart';
import 'package:guar_query/src/helpers.dart';

List<Directive> applySummarize({
  required List<Directive> directives,
  required LedgerOptions options,
  BeanDate? open,
  CloseSpec? close,
  bool? clear,
}) {
  List<Directive> entries = directives;
  if (open != null) {
    entries = openEntries(entries, open, options);
  }
  if (close != null) {
    final BeanDate? date = switch (close) {
      CloseOnDate(:final BeanDate date) => date,
      CloseEnd() => null,
    };
    entries = closeEntries(entries, date, options);
  }
  if (clear == true) {
    entries = clearEntries(entries, null, options);
  }
  return entries;
}

Ledger clamp(Ledger ledger, BeanDate start, BeanDate end) => switch (ledger) {
  LedgerErrors() => ledger,
  LedgerDirectives(
    :final List<Directive> directives,
    :final List<ProcessingError> errors,
    :final List<ProcessingWarning> warnings,
    :final LedgerOptions options,
    :final ProcessingInfo info,
  ) =>
    Ledger.directives(
      directives: _clampEntries(directives, start, end, options),
      errors: errors,
      warnings: warnings,
      options: options,
      info: info,
    ),
};

List<Directive> _clampEntries(List<Directive> entries, BeanDate start, BeanDate end, LedgerOptions options) {
  List<Directive> result = clearEntries(entries, start, options, earnings: options.accountPreviousEarnings);
  result = summarize(result, start, options.accountPreviousBalances);
  return closeEntries(result, end, options);
}

List<Directive> openEntries(List<Directive> entries, BeanDate date, LedgerOptions options) {
  List<Directive> result = conversions(
    entries,
    _conversionsAccount(options, previous: true),
    options.conversionCurrency,
    date,
  );
  result = clearEntries(result, date, options, earnings: options.accountPreviousEarnings);
  return summarize(result, date, options.accountPreviousBalances);
}

List<Directive> closeEntries(List<Directive> entries, BeanDate? date, LedgerOptions options) {
  final List<Directive> result = date == null ? entries : truncate(entries, date);
  return conversions(result, _conversionsAccount(options, previous: false), options.conversionCurrency, date);
}

List<Directive> clearEntries(List<Directive> entries, BeanDate? date, LedgerOptions options, {Account? earnings}) {
  final Account target = earnings ?? options.accountCurrentEarnings;
  return transferBalances(entries, date, isIncomeStatement, target);
}

List<Directive> truncate(List<Directive> entries, BeanDate date) => <Directive>[
  for (final Directive entry in entries)
    if (compareBeanDate(entry.date, date) < 0) entry,
];

List<Directive> transferBalances(
  List<Directive> entries,
  BeanDate? date,
  bool Function(Account account) predicate,
  Account transferAccount,
) {
  if (entries.isEmpty) return entries;
  final (Map<Account, Inventory> balances, int index) = balanceByAccount(entries, date);
  final Map<Account, Inventory> selected = <Account, Inventory>{
    for (final MapEntry<Account, Inventory> entry in balances.entries)
      if (predicate(entry.key)) entry.key: entry.value,
  };
  final BeanDate transferDate = date == null ? entries.last.date : addDays(date, -1);
  final List<Directive> synthesized = createEntriesFromBalances(
    selected,
    transferDate,
    transferAccount,
    direction: false,
    flag: Flag.letter('T'),
    narrationTemplate: "Transfer balance for '{account}' (Transfer balance)",
  );
  final List<Directive> after = <Directive>[
    for (final Directive entry in entries.skip(index))
      if (entry.body is! BalanceBody || !selected.containsKey((entry.body as BalanceBody).account)) entry,
  ];
  return <Directive>[...entries.take(index), ...synthesized, ...after];
}

List<Directive> summarize(List<Directive> entries, BeanDate date, Account opening) {
  final (Map<Account, Inventory> balances, int index) = balanceByAccount(entries, date);
  final BeanDate summarizeDate = addDays(date, -1);
  final List<Directive> summarizing = createEntriesFromBalances(
    balances,
    summarizeDate,
    opening,
    direction: true,
    flag: Flag.letter('S'),
    narrationTemplate: "Opening balance for '{account}' (Summarization)",
  );
  final List<Directive> priceEntries = lastPricesBefore(entries, date);
  final List<Directive> opens = openEntriesAt(entries, date);
  final List<Directive> before = <Directive>[...opens, ...priceEntries, ...summarizing]..sort(_directiveSort);
  return <Directive>[...before, ...entries.skip(index)];
}

List<Directive> conversions(List<Directive> entries, Account account, Currency conversionCurrency, BeanDate? date) {
  final Inventory balance = computeBalance(entries, date);
  final Inventory costBalance = reduceCost(balance);
  if (costBalance.isEmpty) return entries;
  final int index = date == null ? entries.length : _indexAt(entries, date);
  final BeanDate lastDate = date == null ? entries.last.date : addDays(date, -1);
  final List<Posting> postings = <Posting>[];
  for (final Position position in costBalance.positions) {
    final Position negated = -position;
    postings.add(
      Posting(
        origin: const Origin.generated(),
        account: account,
        units: negated.units,
        cost: negated.cost,
        price: Amount(number: Decimal.zero, currency: conversionCurrency),
      ),
    );
  }
  final Directive entry = Directive(
    origin: const Origin.generated(),
    date: lastDate,
    body: DirectiveBody.transaction(
      Transaction(
        origin: const Origin.generated(),
        flag: Flag.letter('C'),
        narration: 'Conversion for $balance',
        postings: postings,
      ),
    ),
  );
  return <Directive>[...entries.take(index), entry, ...entries.skip(index)];
}

(Map<Account, Inventory>, int) balanceByAccount(List<Directive> entries, BeanDate? date) {
  final int index = date == null ? entries.length : _indexAt(entries, date);
  final Map<Account, Inventory> balances = <Account, Inventory>{};
  for (final Directive entry in entries.take(index)) {
    final DirectiveBody body = entry.body;
    if (body is! TransactionBody) continue;
    for (final Posting posting in body.value.postings) {
      final Inventory current = balances[posting.account] ?? const Inventory();
      balances[posting.account] = current.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
    }
  }
  return (balances, index);
}

Inventory computeBalance(List<Directive> entries, BeanDate? date) {
  final int index = date == null ? entries.length : _indexAt(entries, date);
  Inventory inventory = const Inventory();
  for (final Directive entry in entries.take(index)) {
    final DirectiveBody body = entry.body;
    if (body is! TransactionBody) continue;
    for (final Posting posting in body.value.postings) {
      inventory = inventory.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
    }
  }
  return inventory;
}

List<Directive> createEntriesFromBalances(
  Map<Account, Inventory> balances,
  BeanDate date,
  Account sourceAccount, {
  required bool direction,
  required Flag flag,
  required String narrationTemplate,
}) {
  final List<Directive> entries = <Directive>[];
  final List<Account> accounts = balances.keys.toList()..sort((Account a, Account b) => a.name.compareTo(b.name));
  for (final Account account in accounts) {
    Inventory inventory = balances[account]!;
    if (inventory.isEmpty) continue;
    if (!direction) inventory = -inventory;
    final List<Posting> postings = <Posting>[
      for (final Position position in inventory.positions)
        Posting(origin: const Origin.generated(), account: account, units: position.units, cost: position.cost),
    ];
    Inventory sourceInventory = const Inventory();
    for (final Position position in inventory.positions) {
      sourceInventory = sourceInventory.addAmount(-costOf(position)).inventory;
    }
    for (final Position position in sourceInventory.positions) {
      postings.add(
        Posting(origin: const Origin.generated(), account: sourceAccount, units: position.units, cost: position.cost),
      );
    }
    entries.add(
      Directive(
        origin: const Origin.generated(),
        date: date,
        body: DirectiveBody.transaction(
          Transaction(
            origin: const Origin.generated(),
            flag: flag,
            narration: narrationTemplate.replaceAll('{account}', account.name),
            postings: postings,
          ),
        ),
      ),
    );
  }
  return entries;
}

List<Directive> lastPricesBefore(List<Directive> entries, BeanDate date) {
  final Map<String, Directive> last = <String, Directive>{};
  for (final Directive entry in entries) {
    if (compareBeanDate(entry.date, date) >= 0) break;
    final DirectiveBody body = entry.body;
    if (body is PriceBody) {
      last['${body.currency.name}:${body.amount.currency.name}'] = entry;
    }
  }
  return last.values.toList();
}

List<Directive> openEntriesAt(List<Directive> entries, BeanDate date) {
  final Map<String, Directive> opens = <String, Directive>{};
  final Set<String> closed = <String>{};
  for (final Directive entry in entries) {
    if (compareBeanDate(entry.date, date) >= 0) break;
    switch (entry.body) {
      case OpenBody(:final Account account):
        opens[account.name] = entry;
        closed.remove(account.name);
      case CloseBody(:final Account account):
        closed.add(account.name);
      default:
        break;
    }
  }
  return <Directive>[
    for (final MapEntry<String, Directive> entry in opens.entries)
      if (!closed.contains(entry.key)) entry.value,
  ];
}

int _indexAt(List<Directive> entries, BeanDate date) {
  for (int i = 0; i < entries.length; i++) {
    if (compareBeanDate(entries[i].date, date) >= 0) return i;
  }
  return entries.length;
}

int _directiveSort(Directive left, Directive right) {
  final int byDate = compareBeanDate(left.date, right.date);
  if (byDate != 0) return byDate;
  return _typeRank(left.body).compareTo(_typeRank(right.body));
}

int _typeRank(DirectiveBody body) => switch (body) {
  OpenBody() => 0,
  CloseBody() => 1,
  PadBody() => 2,
  BalanceBody() => 3,
  TransactionBody() => 4,
  NoteBody() => 5,
  EventBody() => 6,
  QueryBody() => 7,
  PriceBody() => 8,
  DocumentBody() => 9,
  CustomBody() || BudgetBody() || BudgetOffBody() => 10,
  CommodityBody() => 11,
};

Account _conversionsAccount(LedgerOptions options, {required bool previous}) {
  if (previous) {
    return options.accountPreviousConversions;
  }
  return options.accountCurrentConversions;
}
