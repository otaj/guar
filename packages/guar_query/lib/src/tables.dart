// Beancount named tables over a booked ledger.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_query/src/ast.dart';
import 'package:guar_query/src/convert.dart';
import 'package:guar_query/src/helpers.dart';
import 'package:guar_query/src/summarize.dart';
import 'package:guar_query/src/value.dart';

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
    LedgerDirectives(:final List<Directive> directives) => directives,
    LedgerErrors() => const <Directive>[],
  };

  static LedgerOptions _optionsOf(Ledger ledger) => switch (ledger) {
    LedgerDirectives(:final LedgerOptions options) => options,
    LedgerErrors(:final LedgerOptions options) => options,
  };

  TableEnv withDirectives(List<Directive> next) => TableEnv(ledger, clock: clock, directives: next);
}

abstract class BqlTable {
  String get name;
  Map<String, ColumnSpec> get columns;
  List<String> get wildcardColumns => columns.keys.where((String name) => name != 'meta').toList();
  Iterable<Object> rows();
  // ignore: avoid_returning_this, identity evolve; subclasses return a filtered copy
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
  List<String> get wildcardColumns => const <String>['date', 'flag', 'payee', 'narration', 'position'];

  List<Directive> get _entries {
    if (open == null && close == null && clear != true) return env.directives;
    return applySummarize(directives: env.directives, options: env.options, open: open, close: close, clear: clear);
  }

  @override
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) =>
      PostingsTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);

  @override
  late final Map<String, ColumnSpec> columns = <String, ColumnSpec>{
    'type': ColumnSpec(QueryType.text, (_) => const QueryValue.text('transaction')),
    'id': ColumnSpec(QueryType.text, (Object row) => QueryValue.text(_entryId((row as PostingRow).directive))),
    'date': ColumnSpec(QueryType.date, (Object row) => QueryValue.date((row as PostingRow).directive.date)),
    'year': ColumnSpec(QueryType.integer, (Object row) => QueryValue.integer((row as PostingRow).directive.date.year)),
    'month': ColumnSpec(
      QueryType.integer,
      (Object row) => QueryValue.integer((row as PostingRow).directive.date.month),
    ),
    'day': ColumnSpec(QueryType.integer, (Object row) => QueryValue.integer((row as PostingRow).directive.date.day)),
    'filename': ColumnSpec(QueryType.text, (Object row) => _filename((row as PostingRow).posting.origin)),
    'lineno': ColumnSpec(QueryType.integer, (Object row) => _lineno((row as PostingRow).posting.origin)),
    'location': ColumnSpec(QueryType.text, (Object row) => _location((row as PostingRow).posting.origin)),
    'flag': ColumnSpec(QueryType.flag, (Object row) => QueryValue.flag((row as PostingRow).transaction.flag)),
    'payee': ColumnSpec(QueryType.text, (Object row) {
      final String? payee = (row as PostingRow).transaction.payee;
      return payee == null ? const QueryValue.null_() : QueryValue.text(payee);
    }),
    'narration': ColumnSpec(QueryType.text, (Object row) => QueryValue.text((row as PostingRow).transaction.narration)),
    'description': ColumnSpec(QueryType.text, (Object row) {
      final Transaction tx = (row as PostingRow).transaction;
      return QueryValue.text(
        <String>[if (tx.payee != null) tx.payee!, if (tx.narration.isNotEmpty) tx.narration].join(' | '),
      );
    }),
    'tags': ColumnSpec(QueryType.tags, (Object row) => QueryValue.tags((row as PostingRow).transaction.tags.toSet())),
    'links': ColumnSpec(
      QueryType.links,
      (Object row) => QueryValue.links((row as PostingRow).transaction.links.toSet()),
    ),
    'posting_flag': ColumnSpec(QueryType.flag, (Object row) {
      final Flag? flag = (row as PostingRow).posting.flag;
      return flag == null ? const QueryValue.null_() : QueryValue.flag(flag);
    }),
    'account': ColumnSpec(QueryType.account, (Object row) => QueryValue.account((row as PostingRow).posting.account)),
    'other_accounts': ColumnSpec(QueryType.accounts, (Object row) {
      final PostingRow postingRow = row as PostingRow;
      return QueryValue.accounts(<Account>{
        for (final Posting posting in postingRow.transaction.postings)
          if (!identical(posting, postingRow.posting)) posting.account,
      });
    }),
    'number': ColumnSpec(QueryType.number, (Object row) => QueryValue.number((row as PostingRow).posting.units.number)),
    'currency': ColumnSpec(
      QueryType.currency,
      (Object row) => QueryValue.currency((row as PostingRow).posting.units.currency),
    ),
    'cost_number': ColumnSpec(QueryType.number, (Object row) {
      final Cost? cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.number(cost.number);
    }),
    'cost_currency': ColumnSpec(QueryType.currency, (Object row) {
      final Cost? cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.currency(cost.currency);
    }),
    'cost_date': ColumnSpec(QueryType.date, (Object row) {
      final Cost? cost = (row as PostingRow).posting.cost;
      return cost == null ? const QueryValue.null_() : QueryValue.date(cost.date);
    }),
    'cost_label': ColumnSpec(
      QueryType.text,
      (Object row) => QueryValue.text((row as PostingRow).posting.cost?.label ?? ''),
    ),
    'position': ColumnSpec(QueryType.position, (Object row) {
      final Posting posting = (row as PostingRow).posting;
      return QueryValue.position(Position(units: posting.units, cost: posting.cost));
    }),
    'price': ColumnSpec(QueryType.amount, (Object row) {
      final Amount? price = (row as PostingRow).posting.price;
      return price == null ? const QueryValue.null_() : QueryValue.amount(price);
    }),
    'weight': ColumnSpec(QueryType.amount, (Object row) => QueryValue.amount(weightOf((row as PostingRow).posting))),
    'balance': ColumnSpec(QueryType.inventory, (Object row) => QueryValue.inventory((row as PostingRow).balance)),
    'meta': ColumnSpec(QueryType.meta, (Object row) => QueryValue.meta((row as PostingRow).posting.meta)),
    'entry': ColumnSpec(QueryType.transaction, (Object row) => QueryValue.transaction((row as PostingRow).transaction)),
    'accounts': ColumnSpec(
      QueryType.accounts,
      (Object row) => QueryValue.accounts(<Account>{
        for (final Posting posting in (row as PostingRow).transaction.postings) posting.account,
      }),
    ),
  };

  @override
  Iterable<Object> rows() sync* {
    int rowid = 0;
    Inventory balance = const Inventory();
    for (final Directive directive in _entries) {
      final DirectiveBody body = directive.body;
      if (body is! TransactionBody) continue;
      for (final Posting posting in body.value.postings) {
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
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) =>
      EntriesTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);

  @override
  late final Map<String, ColumnSpec> columns = <String, ColumnSpec>{
    'id': ColumnSpec(QueryType.text, (Object row) => QueryValue.text(_entryId(row as Directive))),
    'type': ColumnSpec(QueryType.text, (Object row) => QueryValue.text(_entryType(row as Directive))),
    'filename': ColumnSpec(QueryType.text, (Object row) => _filename((row as Directive).origin)),
    'lineno': ColumnSpec(QueryType.integer, (Object row) => _lineno((row as Directive).origin)),
    'date': ColumnSpec(QueryType.date, (Object row) => QueryValue.date((row as Directive).date)),
    'year': ColumnSpec(QueryType.integer, (Object row) => QueryValue.integer((row as Directive).date.year)),
    'month': ColumnSpec(QueryType.integer, (Object row) => QueryValue.integer((row as Directive).date.month)),
    'day': ColumnSpec(QueryType.integer, (Object row) => QueryValue.integer((row as Directive).date.day)),
    'flag': ColumnSpec(QueryType.flag, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      return QueryValue.flag(body.value.flag);
    }),
    'payee': ColumnSpec(QueryType.text, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      final String? payee = body.value.payee;
      return payee == null ? const QueryValue.null_() : QueryValue.text(payee);
    }),
    'narration': ColumnSpec(QueryType.text, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      return QueryValue.text(body.value.narration);
    }),
    'description': ColumnSpec(QueryType.text, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is! TransactionBody) return const QueryValue.null_();
      final Transaction tx = body.value;
      return QueryValue.text(
        <String>[if (tx.payee != null) tx.payee!, if (tx.narration.isNotEmpty) tx.narration].join(' | '),
      );
    }),
    'tags': ColumnSpec(QueryType.tags, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is TransactionBody) return QueryValue.tags(body.value.tags.toSet());
      return const QueryValue.null_();
    }),
    'links': ColumnSpec(QueryType.links, (Object row) {
      final DirectiveBody body = (row as Directive).body;
      if (body is TransactionBody) return QueryValue.links(body.value.links.toSet());
      return const QueryValue.null_();
    }),
    'meta': ColumnSpec(QueryType.meta, (Object row) => QueryValue.meta((row as Directive).meta)),
    'accounts': ColumnSpec(QueryType.accounts, (Object row) => QueryValue.accounts(_entryAccounts(row as Directive))),
  };

  @override
  Iterable<Object> rows() => _entries;
}

class TransactionsTable extends EntriesTable {
  TransactionsTable(super.env, {super.open, super.close, super.clear});

  @override
  String get name => 'transactions';

  @override
  BqlTable evolve({BeanDate? open, CloseSpec? close, bool? clear}) =>
      TransactionsTable(env, open: open ?? this.open, close: close ?? this.close, clear: clear ?? this.clear);

  @override
  Iterable<Object> rows() => _entries.where((Directive entry) => entry.body is TransactionBody);
}

class AccountsTable extends BqlTable {
  AccountsTable(this.env);
  final TableEnv env;

  @override
  String get name => 'accounts';

  @override
  late final Map<String, ColumnSpec> columns = <String, ColumnSpec>{
    'account': ColumnSpec(QueryType.account, (Object row) => QueryValue.account((row as AccountRow).account)),
    'open': ColumnSpec(QueryType.directive, (Object row) {
      final Directive? open = (row as AccountRow).open;
      return open == null ? const QueryValue.null_() : QueryValue.directive(open);
    }),
    'close': ColumnSpec(QueryType.directive, (Object row) {
      final Directive? close = (row as AccountRow).close;
      return close == null ? const QueryValue.null_() : QueryValue.directive(close);
    }),
  };

  @override
  Iterable<Object> rows() {
    final Map<String, Directive> opens = <String, Directive>{};
    final Map<String, Directive> closes = <String, Directive>{};
    for (final Directive entry in env.directives) {
      switch (entry.body) {
        case OpenBody(:final Account account):
          opens[account.name] = entry;
        case CloseBody(:final Account account):
          closes[account.name] = entry;
        default:
          break;
      }
    }
    final List<String> names = <String>{...opens.keys, ...closes.keys}.toList()..sort();
    return <Object>[
      for (final String name in names)
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
  Iterable<Object> rows() => env.directives.where((Directive entry) => _match(entry.body));
}

Map<String, BqlTable> beancountTables(TableEnv env) => <String, BqlTable>{
  'postings': PostingsTable(env),
  'entries': EntriesTable(env),
  'transactions': TransactionsTable(env),
  'accounts': AccountsTable(env),
  'prices': TypedEntriesTable(env, 'prices', (DirectiveBody body) => body is PriceBody),
  'balances': TypedEntriesTable(env, 'balances', (DirectiveBody body) => body is BalanceBody),
  'notes': TypedEntriesTable(env, 'notes', (DirectiveBody body) => body is NoteBody),
  'events': TypedEntriesTable(env, 'events', (DirectiveBody body) => body is EventBody),
  'documents': TypedEntriesTable(env, 'documents', (DirectiveBody body) => body is DocumentBody),
  'commodities': TypedEntriesTable(env, 'commodities', (DirectiveBody body) => body is CommodityBody),
  '': PostingsTable(env),
};

QueryValue _filename(Origin origin) => switch (origin) {
  SourceOrigin(:final BeanLocation location) => QueryValue.text(location.filename),
  GeneratedOrigin() => const QueryValue.null_(),
};

QueryValue _lineno(Origin origin) => switch (origin) {
  SourceOrigin(:final BeanLocation location) => QueryValue.integer(location.linenoBegin),
  GeneratedOrigin() => const QueryValue.null_(),
};

QueryValue _location(Origin origin) => switch (origin) {
  SourceOrigin(:final BeanLocation location) => QueryValue.text('${location.filename}:${location.linenoBegin}:'),
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
  BudgetBody() || BudgetOffBody() => 'budget',
};

String _entryId(Directive directive) {
  final DirectiveBody body = directive.body;
  final String payload = switch (body) {
    TransactionBody(:final Transaction value) =>
      '${directive.date}|${flagChar(value.flag)}|${value.narration}|${value.postings.length}',
    _ => '${directive.date}|${_entryType(directive)}',
  };
  return payload.hashCode.toRadixString(16);
}

Set<Account> _entryAccounts(Directive directive) => switch (directive.body) {
  TransactionBody(:final Transaction value) => <Account>{for (final Posting posting in value.postings) posting.account},
  OpenBody(:final Account account) => <Account>{account},
  CloseBody(:final Account account) => <Account>{account},
  BalanceBody(:final Account account) => <Account>{account},
  PadBody(:final Account account, :final Account sourceAccount) => <Account>{account, sourceAccount},
  NoteBody(:final Account account) => <Account>{account},
  DocumentBody(:final Account account) => <Account>{account},
  BudgetBody(:final Account account) || BudgetOffBody(:final Account account) => <Account>{account},
  _ => <Account>{},
};
