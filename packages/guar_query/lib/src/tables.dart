// Beancount named tables over a booked ledger.

import 'package:guar_domain/guar_domain.dart';

import 'ast.dart';
import 'convert.dart';
import 'helpers.dart';
import 'summarize.dart';
import 'value.dart';

class PostingRow {
  PostingRow({
    required this.directive,
    required this.transaction,
    required this.posting,
    required this.rowid,
    required this.balance,
  });

  final Directive directive;
  final Transaction transaction;
  final Posting posting;
  final int rowid;
  final Inventory balance;
}

class AccountRow {
  AccountRow({required this.account, this.open, this.close});

  final Account account;
  final Directive? open;
  final Directive? close;
}

class TableEnv {
  TableEnv(this.ledger, {required this.clock, List<Directive>? directives})
    : directives = directives ?? _directivesOf(ledger),
      options = _optionsOf(ledger),
      prices = PriceMap.build(_directivesOf(ledger));

  final Ledger ledger;
  final List<Directive> directives;
  final LedgerOptions options;
  final PriceMap prices;
  final DateTime Function() clock;

  static List<Directive> _directivesOf(Ledger ledger) => switch (ledger) {
    LedgerDirectives(:final directives) => directives,
    LedgerErrors() => const [],
  };

  static LedgerOptions _optionsOf(Ledger ledger) => switch (ledger) {
    LedgerDirectives(:final options) => options,
    LedgerErrors(:final options) => options,
  };

  TableEnv withDirectives(List<Directive> next) => TableEnv(ledger, clock: clock, directives: next);
}

abstract class BqlTable {
  String get name;
  Map<String, ColumnSpec> get columns;
  List<String> get wildcardColumns => columns.keys.where((name) => name != 'meta').toList();
  Iterable<Object> rows();
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) => this;
}

class ColumnSpec {
  ColumnSpec(this.type, this.read);
  final QueryType type;
  final QueryValue Function(Object row) read;
}

class PostingsTable extends BqlTable {
  PostingsTable(this.env, {this.open, this.close, this.clear});

  final TableEnv env;
  final BeanDate? open;
  final CloseSpec? close;
  final bool? clear;

  @override
  String get name => 'postings';

  @override
  List<String> get wildcardColumns => const ['date', 'flag', 'payee', 'narration', 'position'];

  List<Directive> get _entries {
    if (open == null && close == null && clear != true) return env.directives;
    return applySummarize(directives: env.directives, options: env.options, open: open, close: close, clear: clear);
  }

  @override
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) {
    return PostingsTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);
  }

  @override
  late final Map<String, ColumnSpec> columns = {
    'type': ColumnSpec(QueryType.text, (_) => const QueryValue.text('transaction')),
    'id': ColumnSpec(QueryType.text, (row) => QueryValue.text(_entryId((row as PostingRow).directive))),
    'date': ColumnSpec(QueryType.date, (row) => QueryValue.date((row as PostingRow).directive.date)),
    'year': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as PostingRow).directive.date.year)),
    'month': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as PostingRow).directive.date.month)),
    'day': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as PostingRow).directive.date.day)),
    'filename': ColumnSpec(QueryType.text, (row) => _filename((row as PostingRow).posting.origin)),
    'lineno': ColumnSpec(QueryType.integer, (row) => _lineno((row as PostingRow).posting.origin)),
    'location': ColumnSpec(QueryType.text, (row) => _location((row as PostingRow).posting.origin)),
    'flag': ColumnSpec(QueryType.flag, (row) => QueryValue.flag((row as PostingRow).transaction.flag)),
    'payee': ColumnSpec(QueryType.text, (row) {
      final payee = (row as PostingRow).transaction.payee;
      return payee == null ? const QueryValue.null_() : QueryValue.text(payee);
    }),
    'narration': ColumnSpec(QueryType.text, (row) => QueryValue.text((row as PostingRow).transaction.narration)),
    'description': ColumnSpec(QueryType.text, (row) {
      final tx = (row as PostingRow).transaction;
      return QueryValue.text([if (tx.payee != null) tx.payee!, if (tx.narration.isNotEmpty) tx.narration].join(' | '));
    }),
    'tags': ColumnSpec(QueryType.tags, (row) => QueryValue.tags((row as PostingRow).transaction.tags.toSet())),
    'links': ColumnSpec(QueryType.links, (row) => QueryValue.links((row as PostingRow).transaction.links.toSet())),
    'posting_flag': ColumnSpec(QueryType.flag, (row) {
      final flag = (row as PostingRow).posting.flag;
      return flag == null ? const QueryValue.null_() : QueryValue.flag(flag);
    }),
    'account': ColumnSpec(QueryType.account, (row) => QueryValue.account((row as PostingRow).posting.account)),
    'other_accounts': ColumnSpec(QueryType.accounts, (row) {
      final postingRow = row as PostingRow;
      return QueryValue.accounts({
        for (final posting in postingRow.transaction.postings)
          if (!identical(posting, postingRow.posting)) posting.account,
      });
    }),
    'number': ColumnSpec(QueryType.number, (row) => QueryValue.number((row as PostingRow).posting.units.number)),
    'currency': ColumnSpec(
      QueryType.currency,
      (row) => QueryValue.currency((row as PostingRow).posting.units.currency),
    ),
    'cost_number': ColumnSpec(QueryType.number, (row) {
      final cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.number(cost.number);
    }),
    'cost_currency': ColumnSpec(QueryType.currency, (row) {
      final cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.currency(cost.currency);
    }),
    'cost_date': ColumnSpec(QueryType.date, (row) {
      final cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.date(cost.date);
    }),
    'cost_label': ColumnSpec(QueryType.text, (row) => QueryValue.text((row as PostingRow).posting.cost?.label ?? '')),
    'position': ColumnSpec(QueryType.position, (row) {
      final posting = (row as PostingRow).posting;
      return QueryValue.position(Position(units: posting.units, cost: posting.cost));
    }),
    'price': ColumnSpec(QueryType.amount, (row) {
      final price = (row as PostingRow).posting.price;
      return price == null ? const QueryValue.null_() : QueryValue.amount(price);
    }),
    'weight': ColumnSpec(QueryType.amount, (row) => QueryValue.amount(weightOf((row as PostingRow).posting))),
    'balance': ColumnSpec(QueryType.inventory, (row) => QueryValue.inventory((row as PostingRow).balance)),
    'meta': ColumnSpec(QueryType.meta, (row) => QueryValue.meta((row as PostingRow).posting.meta)),
    'entry': ColumnSpec(QueryType.transaction, (row) => QueryValue.transaction((row as PostingRow).transaction)),
    'accounts': ColumnSpec(QueryType.accounts, (row) {
      return QueryValue.accounts({for (final posting in (row as PostingRow).transaction.postings) posting.account});
    }),
  };

  @override
  Iterable<Object> rows() sync* {
    var rowid = 0;
    var balance = const Inventory();
    for (final directive in _entries) {
      final body = directive.body;
      if (body is! TransactionBody) continue;
      for (final posting in body.value.postings) {
        rowid += 1;
        balance = balance.addPosition(Position(units: posting.units, cost: posting.cost)).inventory;
        yield PostingRow(
          directive: directive,
          transaction: body.value,
          posting: posting,
          rowid: rowid,
          balance: balance,
        );
      }
    }
  }
}

class EntriesTable extends BqlTable {
  EntriesTable(this.env, {this.open, this.close, this.clear});

  final TableEnv env;
  final BeanDate? open;
  final CloseSpec? close;
  final bool? clear;

  @override
  String get name => 'entries';

  List<Directive> get _entries {
    if (open == null && close == null && clear != true) return env.directives;
    return applySummarize(directives: env.directives, options: env.options, open: open, close: close, clear: clear);
  }

  @override
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) {
    return EntriesTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);
  }

  @override
  late final Map<String, ColumnSpec> columns = {
    'id': ColumnSpec(QueryType.text, (row) => QueryValue.text(_entryId(row as Directive))),
    'type': ColumnSpec(QueryType.text, (row) => QueryValue.text(_entryType(row as Directive))),
    'filename': ColumnSpec(QueryType.text, (row) => _filename((row as Directive).origin)),
    'lineno': ColumnSpec(QueryType.integer, (row) => _lineno((row as Directive).origin)),
    'date': ColumnSpec(QueryType.date, (row) => QueryValue.date((row as Directive).date)),
    'year': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as Directive).date.year)),
    'month': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as Directive).date.month)),
    'day': ColumnSpec(QueryType.integer, (row) => QueryValue.integer((row as Directive).date.day)),
    'flag': ColumnSpec(QueryType.flag, (row) {
      final body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      return QueryValue.flag(body.value.flag);
    }),
    'payee': ColumnSpec(QueryType.text, (row) {
      final body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      final payee = body.value.payee;
      return payee == null ? const QueryValue.null_() : QueryValue.text(payee);
    }),
    'narration': ColumnSpec(QueryType.text, (row) {
      final body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      return QueryValue.text(body.value.narration);
    }),
    'description': ColumnSpec(QueryType.text, (row) {
      final body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      final tx = body.value;
      return QueryValue.text([if (tx.payee != null) tx.payee!, if (tx.narration.isNotEmpty) tx.narration].join(' | '));
    }),
    'tags': ColumnSpec(QueryType.tags, (row) {
      final body = (row as Directive).body;
      if (body is TransactionBody) return QueryValue.tags(body.value.tags.toSet());
      return const QueryValue.null_();
    }),
    'links': ColumnSpec(QueryType.links, (row) {
      final body = (row as Directive).body;
      if (body is TransactionBody) return QueryValue.links(body.value.links.toSet());
      return const QueryValue.null_();
    }),
    'meta': ColumnSpec(QueryType.meta, (row) => QueryValue.meta((row as Directive).meta)),
    'accounts': ColumnSpec(QueryType.accounts, (row) => QueryValue.accounts(_entryAccounts(row as Directive))),
  };

  @override
  Iterable<Object> rows() => _entries;
}

class TransactionsTable extends EntriesTable {
  TransactionsTable(super.env, {super.open, super.close, super.clear});

  @override
  String get name => 'transactions';

  @override
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) {
    return TransactionsTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);
  }

  @override
  Iterable<Object> rows() => _entries.where((entry) => entry.body is TransactionBody);
}

class AccountsTable extends BqlTable {
  AccountsTable(this.env);
  final TableEnv env;

  @override
  String get name => 'accounts';

  @override
  late final Map<String, ColumnSpec> columns = {
    'account': ColumnSpec(QueryType.account, (row) => QueryValue.account((row as AccountRow).account)),
    'open': ColumnSpec(QueryType.directive, (row) {
      final open = (row as AccountRow).open;
      return open == null ? const QueryValue.null_() : QueryValue.directive(open);
    }),
    'close': ColumnSpec(QueryType.directive, (row) {
      final close = (row as AccountRow).close;
      return close == null ? const QueryValue.null_() : QueryValue.directive(close);
    }),
  };

  @override
  Iterable<Object> rows() {
    final opens = <String, Directive>{};
    final closes = <String, Directive>{};
    for (final entry in env.directives) {
      switch (entry.body) {
        case OpenBody(:final account):
          opens[account.name] = entry;
        case CloseBody(:final account):
          closes[account.name] = entry;
        default:
          break;
      }
    }
    final names = {...opens.keys, ...closes.keys}.toList()..sort();
    return [
      for (final name in names)
        AccountRow(account: accountFor(name, env.options), open: opens[name], close: closes[name]),
    ];
  }
}

class TypedEntriesTable extends BqlTable {
  TypedEntriesTable(this.env, this.name, this._match);
  final TableEnv env;
  @override
  final String name;
  final bool Function(DirectiveBody body) _match;

  @override
  late final Map<String, ColumnSpec> columns = EntriesTable(env).columns;

  @override
  Iterable<Object> rows() => env.directives.where((entry) => _match(entry.body));
}

Map<String, BqlTable> beancountTables(TableEnv env) {
  return {
    'postings': PostingsTable(env),
    'entries': EntriesTable(env),
    'transactions': TransactionsTable(env),
    'accounts': AccountsTable(env),
    'prices': TypedEntriesTable(env, 'prices', (body) => body is PriceBody),
    'balances': TypedEntriesTable(env, 'balances', (body) => body is BalanceBody),
    'notes': TypedEntriesTable(env, 'notes', (body) => body is NoteBody),
    'events': TypedEntriesTable(env, 'events', (body) => body is EventBody),
    'documents': TypedEntriesTable(env, 'documents', (body) => body is DocumentBody),
    'commodities': TypedEntriesTable(env, 'commodities', (body) => body is CommodityBody),
    '': PostingsTable(env),
  };
}

QueryValue _filename(Origin origin) => switch (origin) {
  SourceOrigin(:final location) => QueryValue.text(location.filename),
  GeneratedOrigin() => const QueryValue.null_(),
};

QueryValue _lineno(Origin origin) => switch (origin) {
  SourceOrigin(:final location) => QueryValue.integer(location.linenoBegin),
  GeneratedOrigin() => const QueryValue.null_(),
};

QueryValue _location(Origin origin) => switch (origin) {
  SourceOrigin(:final location) => QueryValue.text('${location.filename}:${location.linenoBegin}:'),
  GeneratedOrigin() => const QueryValue.null_(),
};

String _entryType(Directive directive) => switch (directive.body) {
  TransactionBody() => 'transaction',
  PriceBody() => 'price',
  BalanceBody() => 'balance',
  OpenBody() => 'open',
  CloseBody() => 'close',
  CommodityBody() => 'commodity',
  PadBody() => 'pad',
  DocumentBody() => 'document',
  NoteBody() => 'note',
  EventBody() => 'event',
  QueryBody() => 'query',
  CustomBody() => 'custom',
};

String _entryId(Directive directive) {
  final body = directive.body;
  final payload = switch (body) {
    TransactionBody(:final value) =>
      '${directive.date}|${flagChar(value.flag)}|${value.narration}|${value.postings.length}',
    _ => '${directive.date}|${_entryType(directive)}',
  };
  return payload.hashCode.toRadixString(16);
}

Set<Account> _entryAccounts(Directive directive) => switch (directive.body) {
  TransactionBody(:final value) => {for (final posting in value.postings) posting.account},
  OpenBody(:final account) => {account},
  CloseBody(:final account) => {account},
  BalanceBody(:final account) => {account},
  PadBody(:final account, :final sourceAccount) => {account, sourceAccount},
  NoteBody(:final account) => {account},
  DocumentBody(:final account) => {account},
  _ => {},
};
