// Cell values for BQL query results, wrapping guar_domain types.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guar_domain/guar_domain.dart';

part 'value.freezed.dart';

enum QueryType {
  null_,
  boolean,
  integer,
  number,
  text,
  date,
  account,
  currency,
  amount,
  position,
  cost,
  inventory,
  meta,
  tags,
  links,
  accounts,
  flag,
  directive,
  transaction,
  interval,
  set,
  object,
  asterisk,
}

@freezed
sealed class QueryValue with _$QueryValue {
  const QueryValue._();

  const factory QueryValue.null_() = QueryNull;
  // ignore: avoid_positional_boolean_parameters, bool is the stored payload
  const factory QueryValue.boolean(bool value) = QueryBoolean;
  const factory QueryValue.integer(int value) = QueryInteger;
  const factory QueryValue.number(Decimal value) = QueryNumber;
  const factory QueryValue.text(String value) = QueryText;
  const factory QueryValue.date(BeanDate value) = QueryDate;
  const factory QueryValue.account(Account value) = QueryAccount;
  const factory QueryValue.currency(Currency value) = QueryCurrency;
  const factory QueryValue.amount(Amount value) = QueryAmount;
  const factory QueryValue.position(Position value) = QueryPosition;
  const factory QueryValue.cost(Cost value) = QueryCost;
  const factory QueryValue.inventory(Inventory value) = QueryInventory;
  const factory QueryValue.meta(Meta value) = QueryMeta;
  const factory QueryValue.metaValue(MetaValue value) = QueryMetaCell;
  const factory QueryValue.tags(Set<Tag> value) = QueryTags;
  const factory QueryValue.links(Set<Link> value) = QueryLinks;
  const factory QueryValue.accounts(Set<Account> value) = QueryAccounts;
  const factory QueryValue.flag(Flag value) = QueryFlag;
  const factory QueryValue.directive(Directive value) = QueryDirective;
  const factory QueryValue.transaction(Transaction value) = QueryTransaction;
  const factory QueryValue.interval(DateDelta value) = QueryInterval;
  const factory QueryValue.set(Set<String> value) = QueryStringSet;
  const factory QueryValue.list(List<QueryValue> value) = QueryList;

  bool get isNull => this is QueryNull;

  QueryType get type => switch (this) {
    QueryNull() => QueryType.null_,
    QueryBoolean() => QueryType.boolean,
    QueryInteger() => QueryType.integer,
    QueryNumber() => QueryType.number,
    QueryText() => QueryType.text,
    QueryDate() => QueryType.date,
    QueryAccount() => QueryType.account,
    QueryCurrency() => QueryType.currency,
    QueryAmount() => QueryType.amount,
    QueryPosition() => QueryType.position,
    QueryCost() => QueryType.cost,
    QueryInventory() => QueryType.inventory,
    QueryMeta() => QueryType.meta,
    QueryMetaCell(:final MetaValue value) => metaValueType(value),
    QueryTags() => QueryType.tags,
    QueryLinks() => QueryType.links,
    QueryAccounts() => QueryType.accounts,
    QueryFlag() => QueryType.flag,
    QueryDirective() => QueryType.directive,
    QueryTransaction() => QueryType.transaction,
    QueryInterval() => QueryType.interval,
    QueryStringSet() => QueryType.set,
    QueryList() => QueryType.set,
  };

  String? asText() => switch (this) {
    QueryText(:final String value) => value,
    QueryAccount(:final Account value) => value.name,
    QueryCurrency(:final Currency value) => value.name,
    QueryFlag(:final Flag value) => flagChar(value),
    _ => null,
  };
}

QueryType metaValueType(MetaValue value) => switch (value) {
  MetaText() => QueryType.text,
  MetaAccount() => QueryType.account,
  MetaCurrency() => QueryType.currency,
  MetaTag() => QueryType.text,
  MetaDate() => QueryType.date,
  MetaBoolean() => QueryType.boolean,
  MetaNumber() => QueryType.number,
  MetaAmount() => QueryType.amount,
};

String flagChar(Flag flag) => switch (flag) {
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

Flag? parseFlag(String? text) {
  if (text == null || text.isEmpty) return null;
  return switch (text) {
    '*' => const Flag.special(SpecialFlag.asterisk),
    '!' => const Flag.special(SpecialFlag.exclamation),
    '#' => const Flag.special(SpecialFlag.hash),
    '&' => const Flag.special(SpecialFlag.ampersand),
    '?' => const Flag.special(SpecialFlag.question),
    '%' => const Flag.special(SpecialFlag.percent),
    _ when text.length == 1 && RegExp(r'^[A-Z]$').hasMatch(text) => Flag.letter(text),
    _ => null,
  };
}

QueryValue queryValueFromLiteral(Object? value) {
  if (value == null) return const QueryValue.null_();
  if (value is bool) return QueryValue.boolean(value);
  if (value is int) return QueryValue.integer(value);
  if (value is Decimal) return QueryValue.number(value);
  if (value is String) return QueryValue.text(value);
  if (value is BeanDate) return QueryValue.date(value);
  if (value is List) {
    return QueryValue.list(<QueryValue>[for (final dynamic item in value) queryValueFromLiteral(item)]);
  }
  if (value is QueryValue) return value;
  return QueryValue.text('$value');
}
