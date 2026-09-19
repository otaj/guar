// Stable MD5 of a booked directive's date and body (origin and meta excluded).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:guar_domain/src/account.dart';

import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/cost.dart';
import 'package:guar_domain/src/date.dart';
import 'package:guar_domain/src/directive.dart';
import 'package:guar_domain/src/flag.dart';
import 'package:guar_domain/src/posting.dart';
import 'package:guar_domain/src/transaction.dart';

String hashDirective(BeanDate date, DirectiveBody body) {
  final _HashSink sink = _HashSink()
    ..add(date.toString())
    ..add(_body(body));
  return sink.digest();
}

String _body(DirectiveBody body) => switch (body) {
  TransactionBody(:final Transaction value) => _join(<String>[
    'transaction',
    _flag(value.flag),
    value.payee ?? '',
    value.narration,
    _sorted(value.tags.map((Tag tag) => tag.name)),
    _sorted(value.links.map((Link link) => link.name)),
    _join(<String>[for (final Posting posting in value.postings) _posting(posting)]),
  ]),
  OpenBody(:final Account account, :final List<Currency> currencies, :final BookingMethod? booking) => _join(<String>[
    'open',
    account.name,
    _sorted(currencies.map((Currency currency) => currency.name)),
    booking?.name ?? '',
  ]),
  CloseBody(:final Account account) => _join(<String>['close', account.name]),
  CommodityBody(:final Currency currency) => _join(<String>['commodity', currency.name]),
  PriceBody(:final Currency currency, :final Amount amount) => _join(<String>['price', currency.name, _amount(amount)]),
  BalanceBody(:final Account account, :final Amount amount, :final Decimal? tolerance) => _join(<String>[
    'balance',
    account.name,
    _amount(amount),
    tolerance?.toString() ?? '',
  ]),
  PadBody(:final Account account, :final Account sourceAccount) => _join(<String>[
    'pad',
    account.name,
    sourceAccount.name,
  ]),
  DocumentBody(:final Account account, :final String filename, :final List<Tag> tags, :final List<Link> links) => _join(
    <String>[
      'document',
      account.name,
      filename,
      _sorted(tags.map((Tag tag) => tag.name)),
      _sorted(links.map((Link link) => link.name)),
    ],
  ),
  NoteBody(:final Account account, :final String comment, :final List<Tag> tags, :final List<Link> links) => _join(
    <String>[
      'note',
      account.name,
      comment,
      _sorted(tags.map((Tag tag) => tag.name)),
      _sorted(links.map((Link link) => link.name)),
    ],
  ),
  EventBody(:final String name, :final String description) => _join(<String>['event', name, description]),
  QueryBody(:final String name, :final String queryString) => _join(<String>['query', name, queryString]),
  CustomBody(:final String type, :final List<CustomValue> values) => _join(<String>[
    'custom',
    type,
    _join(<String>[for (final CustomValue value in values) _custom(value)]),
  ]),
  BudgetBody(:final Account account, :final BudgetInterval interval, :final Amount amount) => _join(<String>[
    'budget',
    account.name,
    interval.name,
    _amount(amount),
  ]),
  BudgetOffBody(:final Account account, :final Currency? currency) =>
    currency == null
        ? _join(<String>['budget-off', account.name])
        : _join(<String>['budget-off', account.name, currency.name]),
};

String _posting(Posting posting) => _join(<String>[
  if (posting.flag == null) '' else _flag(posting.flag!),
  posting.account.name,
  _amount(posting.units),
  if (posting.cost == null) '' else _cost(posting.cost!),
  if (posting.price == null) '' else _amount(posting.price!),
]);

String _custom(CustomValue value) => switch (value) {
  CustomText(:final String value) => 'text:$value',
  CustomAccount(:final Account value) => 'account:${value.name}',
  CustomDate(:final BeanDate value) => 'date:$value',
  CustomBoolean(:final bool value) => 'bool:$value',
  CustomNumber(:final Decimal value) => 'number:$value',
  CustomAmount(:final Amount value) => 'amount:${_amount(value)}',
  CustomCurrency(:final Currency value) => 'currency:${value.name}',
};

String _amount(Amount amount) => '${amount.number}|${amount.scale}|${amount.currency.name}';

String _cost(Cost cost) => '${cost.number}|${cost.currency.name}|${cost.date}|${cost.label ?? ''}';

String _flag(Flag flag) => switch (flag) {
  SpecialFlagValue(:final SpecialFlag value) => switch (value) {
    SpecialFlag.asterisk => '*',
    SpecialFlag.exclamation => '!',
    SpecialFlag.hash => '#',
    SpecialFlag.ampersand => '&',
    SpecialFlag.question => '?',
    SpecialFlag.percent => '%',
  },
  LetterFlag(:final String value) => value,
};

String _sorted(Iterable<String> values) {
  final List<String> sorted = values.toList()..sort();
  return _join(sorted);
}

String _join(Iterable<String> parts) => parts.map((String part) => '${part.length}:$part').join('|');

class _HashSink {
  final List<int> _chunks = <int>[];

  void add(String value) {
    _chunks.addAll(utf8.encode('${value.length}:$value;'));
  }

  String digest() => md5.convert(_chunks).toString();
}
