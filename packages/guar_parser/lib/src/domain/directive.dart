// Dated Beancount directives produced by the parser.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/amount.dart';
import 'package:guar_parser/src/domain/date.dart';
import 'package:guar_parser/src/domain/location.dart';
import 'package:guar_parser/src/domain/meta.dart';
import 'package:guar_parser/src/domain/number.dart';
import 'package:guar_parser/src/domain/transaction.dart';

part 'directive.freezed.dart';

enum BookingMethod { strict, strictWithSize, none, average, fifo, lifo, hifo }

@freezed
sealed class CustomValue with _$CustomValue {
  const factory CustomValue.text(String value) = CustomText;
  const factory CustomValue.account(Account value) = CustomAccount;
  const factory CustomValue.date(BeanDate value) = CustomDate;
  // ignore: avoid_positional_boolean_parameters, bool is the stored payload
  const factory CustomValue.boolean(bool value) = CustomBoolean;
  const factory CustomValue.number(BeanNumber value) = CustomNumber;
  const factory CustomValue.amount(Amount value) = CustomAmount;
  const factory CustomValue.currency(Currency value) = CustomCurrency;
}

@freezed
sealed class DirectiveBody with _$DirectiveBody {
  const factory DirectiveBody.transaction(ParsedTransaction value) = TransactionBody;
  const factory DirectiveBody.price({required Currency currency, required Amount amount}) = PriceBody;
  const factory DirectiveBody.balance({required Account account, required Amount amount, BeanNumber? tolerance}) =
      BalanceBody;
  const factory DirectiveBody.open({
    required Account account,
    @Default(<dynamic>[]) List<Currency> currencies,
    BookingMethod? booking,
  }) = OpenBody;
  const factory DirectiveBody.close({required Account account}) = CloseBody;
  const factory DirectiveBody.commodity({required Currency currency}) = CommodityBody;
  const factory DirectiveBody.pad({required Account account, required Account sourceAccount}) = PadBody;
  const factory DirectiveBody.document({
    required Account account,
    required String filename,
    @Default(<dynamic>[]) List<Tag> tags,
    @Default(<dynamic>[]) List<Link> links,
  }) = DocumentBody;
  const factory DirectiveBody.note({
    required Account account,
    required String comment,
    @Default(<dynamic>[]) List<Tag> tags,
    @Default(<dynamic>[]) List<Link> links,
  }) = NoteBody;
  const factory DirectiveBody.event({required String name, required String description}) = EventBody;
  const factory DirectiveBody.query({required String name, required String queryString}) = QueryBody;
  const factory DirectiveBody.custom({required String type, @Default(<dynamic>[]) List<CustomValue> values}) =
      CustomBody;
}

@freezed
abstract class ParsedDirective with _$ParsedDirective {
  const factory ParsedDirective({
    required BeanLocation location,
    required BeanDate date,
    required DirectiveBody body,
    @Default(Meta()) Meta meta,
  }) = _ParsedDirective;
}

@freezed
abstract class ParseError with _$ParseError {
  const factory ParseError({required String message, required BeanLocation location}) = _ParseError;
}

@freezed
abstract class ParseWarning with _$ParseWarning {
  const factory ParseWarning({required String message, required BeanLocation location}) = _ParseWarning;
}
