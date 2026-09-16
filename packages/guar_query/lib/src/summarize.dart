// Query-time OPEN / CLOSE / CLEAR and clamp_opt date-window summarization.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import 'ast.dart';
import 'convert.dart';
import 'helpers.dart';

List<Directive> applySummarize({
  required List<Directive> directives,
  required LedgerOptions options,
  BeanDate? open,
  CloseSpec? close,
  bool? clear,
}) {
  var entries = directives;
  if (open != null) {
    entries = openEntries(entries, open, options);
  }
  if (close != null) {
    final date = switch (close) {
      CloseOnDate(:final date) => date,
      CloseEnd() => null,
    };
    entries = closeEntries(entries, date, options);
  }
  if (clear == true) {
    entries = clearEntries(entries, null, options);
  }
  return entries;
}

Ledger clamp(Ledger ledger, BeanDate start, BeanDate end) {
  return switch (ledger) {
    LedgerErrors() => ledger,
    LedgerDirectives(:final directives, :final errors, :final options, :final info) => Ledger.directives(
      directives: _clampEntries(directives, start, end, options),
      errors: errors,
      options: options,
      info: info,
    ),
  };
}

List<Directive> _clampEntries(List<Directive> entries, BeanDate start, BeanDate end, LedgerOptions options) {
  var result = clearEntries(entries, start, options, earnings: options.accountPreviousEarnings);
  result = summarize(result, start, options.accountPreviousBalances);
  return closeEntries(result, end, options);
}

List<Directive> openEntries(List<Directive> entries, BeanDate date, LedgerOptions options) {
  var result = conversions(entries, _conversionsAccount(options, previous: true), options.conversionCurrency, date);
  result = clearEntries(result, date, options, earnings: options.accountPreviousEarnings);
  return summarize(result, date, options.accountPreviousBalances);
}

List<Directive> closeEntries(List<Directive> entries, BeanDate? date, LedgerOptions options) {
  var result = date == null ? entries : truncate(entries, date);
  return conversions(result, _conversionsAccount(options, previous: false), options.conversionCurrency, date);
}

List<Directive> clearEntries(List<Directive> entries, BeanDate? date, LedgerOptions options, {Account? earnings}) {
  final target = earnings ?? options.accountCurrentEarnings;
  return transferBalances(entries, date, isIncomeStatement, target);
}

List<Directive> truncate(List<Directive> entries, BeanDate date) {
  return [
    for (final entry in entries)
      if (compareBeanDate(entry.date, date) < 0) entry,
  ];
}

List<Directive> transferBalances(
  List<Directive> entries,
  BeanDate? date,
  bool Function(Account account) predicate,
  Account transferAccount,
) {
  if (entries.isEmpty) return entries;
  final (balances, index) = balanceByAccount(entries, date);
  final selected = <Account, Inventory>{
    for (final entry in balances.entries)
      if (predicate(entry.key)) entry.key: entry.value,
  };
  final transferDate = date == null ? entries.last.date : addDays(date, -1);
  final synthesized = createEntriesFromBalances(
    selected,
    transferDate,
    transferAccount,
    direction: false,
    flag: Flag.letter('T'),
    narrationTemplate: "Transfer balance for '{account}' (Transfer balance)",
  );
  final after = [
    for (final entry in entries.skip(index))
      if (entry.body is! BalanceBody || !selected.containsKey((entry.body as BalanceBody).account)) entry,
  ];
  return [...entries.take(index), ...synthesized, ...after];
}

List<Directive> summarize(List<Directive> entries, BeanDate date, Account opening) {
  final (balances, index) = balanceByAccount(entries, date);
  final summarizeDate = addDays(date, -1);
  final summarizing = createEntriesFromBalances(
    balances,
    summarizeDate,
    opening,
    direction: true,
    flag: Flag.letter('S'),
    narrationTemplate: "Opening balance for '{account}' (Summarization)",
  );
  final priceEntries = lastPricesBefore(entries, date);
  final opens = openEntriesAt(entries, date);
  final before = [...opens, ...priceEntries, ...summarizing]..sort(_directiveSort);
  return [...before, ...entries.skip(index)];
}

List<Directive> conversions(List<Directive> entries, Account account, Currency conversionCurrency, BeanDate? date) {
  final balance = computeBalance(entries, date);
  final costBalance = reduceCost(balance);
  if (costBalance.isEmpty) return entries;
  final index = date == null ? entries.length : _indexAt(entries, date);
  final lastDate = date == null ? entries.last.date : addDays(date, -1);
  final postings = <Posting>[];
  for (final position in costBalance.positions) {
    final negated = -position;
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
  final entry = Directive(
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
  return [...entries.take(index), entry, ...entries.skip(index)];
}

(Map<Account, Inventory>, int) balanceByAccount(List<Directive> entries, BeanDate? date) {
  final index = date == null ? entries.length : _indexAt(entries, date);
  final balances = <Account, Inventory>{};
  for (final entry in entries.take(index)) {
    final body = entry.body;
    if (body is! TransactionBody) continue;
    for (final posting in body.value.postings) {
      final current = balances[posting.account] ?? const Inventory();
      balances[posting.account] = current.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
    }
  }
  return (balances, index);
}

Inventory computeBalance(List<Directive> entries, BeanDate? date) {
  final index = date == null ? entries.length : _indexAt(entries, date);
  var inventory = const Inventory();
  for (final entry in entries.take(index)) {
    final body = entry.body;
    if (body is! TransactionBody) continue;
    for (final posting in body.value.postings) {
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
  final entries = <Directive>[];
  final accounts = balances.keys.toList()..sort((a, b) => a.name.compareTo(b.name));
  for (final account in accounts) {
    var inventory = balances[account]!;
    if (inventory.isEmpty) continue;
    if (!direction) inventory = -inventory;
    final postings = <Posting>[
      for (final position in inventory.positions)
        Posting(origin: const Origin.generated(), account: account, units: position.units, cost: position.cost),
    ];
    var sourceInventory = const Inventory();
    for (final position in inventory.positions) {
      sourceInventory = sourceInventory.addAmount(-costOf(position)).inventory;
    }
    for (final position in sourceInventory.positions) {
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
  final last = <String, Directive>{};
  for (final entry in entries) {
    if (compareBeanDate(entry.date, date) >= 0) break;
    final body = entry.body;
    if (body is PriceBody) {
      last['${body.currency.name}:${body.amount.currency.name}'] = entry;
    }
  }
  return last.values.toList();
}

List<Directive> openEntriesAt(List<Directive> entries, BeanDate date) {
  final opens = <String, Directive>{};
  final closed = <String>{};
  for (final entry in entries) {
    if (compareBeanDate(entry.date, date) >= 0) break;
    switch (entry.body) {
      case OpenBody(:final account):
        opens[account.name] = entry;
        closed.remove(account.name);
      case CloseBody(:final account):
        closed.add(account.name);
      default:
        break;
    }
  }
  return [
    for (final entry in opens.entries)
      if (!closed.contains(entry.key)) entry.value,
  ];
}

int _indexAt(List<Directive> entries, BeanDate date) {
  for (var i = 0; i < entries.length; i++) {
    if (compareBeanDate(entries[i].date, date) >= 0) return i;
  }
  return entries.length;
}

int _directiveSort(Directive left, Directive right) {
  final byDate = compareBeanDate(left.date, right.date);
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
  CustomBody() => 10,
  CommodityBody() => 11,
};

Account _conversionsAccount(LedgerOptions options, {required bool previous}) {
  if (previous) {
    return options.accountPreviousConversions;
  }
  return options.accountCurrentConversions;
}
