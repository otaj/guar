// Stable MD5 of a booked directive's date and body (origin and meta excluded).

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'amount.dart';
import 'cost.dart';
import 'date.dart';
import 'directive.dart';
import 'flag.dart';
import 'posting.dart';

String hashDirective(BeanDate date, DirectiveBody body) {
  final sink = _HashSink()
    ..add(date.toString())
    ..add(_body(body));
  return sink.digest();
}

String _body(DirectiveBody body) {
  return switch (body) {
    TransactionBody(:final value) => _join([
      'transaction',
      _flag(value.flag),
      value.payee ?? '',
      value.narration,
      _sorted(value.tags.map((tag) => tag.name)),
      _sorted(value.links.map((link) => link.name)),
      _join([for (final posting in value.postings) _posting(posting)]),
    ]),
    OpenBody(:final account, :final currencies, :final booking) => _join([
      'open',
      account.name,
      _sorted(currencies.map((currency) => currency.name)),
      booking?.name ?? '',
    ]),
    CloseBody(:final account) => _join(['close', account.name]),
    CommodityBody(:final currency) => _join(['commodity', currency.name]),
    PriceBody(:final currency, :final amount) => _join(['price', currency.name, _amount(amount)]),
    BalanceBody(:final account, :final amount, :final tolerance) => _join([
      'balance',
      account.name,
      _amount(amount),
      tolerance?.toString() ?? '',
    ]),
    PadBody(:final account, :final sourceAccount) => _join(['pad', account.name, sourceAccount.name]),
    DocumentBody(:final account, :final filename, :final tags, :final links) => _join([
      'document',
      account.name,
      filename,
      _sorted(tags.map((tag) => tag.name)),
      _sorted(links.map((link) => link.name)),
    ]),
    NoteBody(:final account, :final comment, :final tags, :final links) => _join([
      'note',
      account.name,
      comment,
      _sorted(tags.map((tag) => tag.name)),
      _sorted(links.map((link) => link.name)),
    ]),
    EventBody(:final name, :final description) => _join(['event', name, description]),
    QueryBody(:final name, :final queryString) => _join(['query', name, queryString]),
    CustomBody(:final type, :final values) => _join([
      'custom',
      type,
      _join([for (final value in values) _custom(value)]),
    ]),
  };
}

String _posting(Posting posting) {
  return _join([
    posting.flag == null ? '' : _flag(posting.flag!),
    posting.account.name,
    _amount(posting.units),
    posting.cost == null ? '' : _cost(posting.cost!),
    posting.price == null ? '' : _amount(posting.price!),
  ]);
}

String _custom(CustomValue value) {
  return switch (value) {
    CustomText(:final value) => 'text:$value',
    CustomAccount(:final value) => 'account:${value.name}',
    CustomDate(:final value) => 'date:$value',
    CustomBoolean(:final value) => 'bool:$value',
    CustomNumber(:final value) => 'number:$value',
    CustomAmount(:final value) => 'amount:${_amount(value)}',
  };
}

String _amount(Amount amount) => '${amount.number}|${amount.scale}|${amount.currency.name}';

String _cost(Cost cost) => '${cost.number}|${cost.currency.name}|${cost.date}|${cost.label ?? ''}';

String _flag(Flag flag) => switch (flag) {
  SpecialFlagValue(:final value) => switch (value) {
    SpecialFlag.asterisk => '*',
    SpecialFlag.exclamation => '!',
    SpecialFlag.hash => '#',
    SpecialFlag.ampersand => '&',
    SpecialFlag.question => '?',
    SpecialFlag.percent => '%',
  },
  LetterFlag(:final value) => value,
};

String _sorted(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return _join(sorted);
}

String _join(Iterable<String> parts) => parts.map((part) => '${part.length}:$part').join('|');

class _HashSink {
  final _chunks = <int>[];

  void add(String value) {
    _chunks.addAll(utf8.encode('${value.length}:$value;'));
  }

  String digest() => md5.convert(_chunks).toString();
}
