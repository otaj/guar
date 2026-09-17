// Key/value metadata with computed decimals after booking.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'date.dart';

part 'meta.freezed.dart';

@freezed
sealed class MetaValue with _$MetaValue {
  const factory MetaValue.text(String value) = MetaText;
  const factory MetaValue.account(Account value) = MetaAccount;
  const factory MetaValue.currency(Currency value) = MetaCurrency;
  const factory MetaValue.tag(Tag value) = MetaTag;
  const factory MetaValue.date(BeanDate value) = MetaDate;
  const factory MetaValue.boolean(bool value) = MetaBoolean;
  const factory MetaValue.number(Decimal value) = MetaNumber;
  const factory MetaValue.amount(Amount value) = MetaAmount;
}

@freezed
abstract class MetaEntry with _$MetaEntry {
  const factory MetaEntry({required String key, MetaValue? value}) = _MetaEntry;
}

@freezed
abstract class Meta with _$Meta {
  const Meta._();

  const factory Meta({@Default([]) List<MetaEntry> entries}) = _Meta;

  MetaValue? lookup(String key) {
    for (final entry in entries) {
      if (entry.key == key) return entry.value;
    }
    return null;
  }
}
