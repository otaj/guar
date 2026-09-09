// Dated Beancount directives produced by the parser.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'date.dart';
import 'location.dart';
import 'meta.dart';
import 'number.dart';
import 'transaction.dart';

part 'directive.freezed.dart';

enum BookingMethod { strict, strictWithSize, none, average, fifo, lifo, hifo }

@freezed
sealed class CustomValue with _$CustomValue {
  const factory CustomValue.text(String value) = CustomText;
  const factory CustomValue.account(Account value) = CustomAccount;
  const factory CustomValue.date(BeanDate value) = CustomDate;
  const factory CustomValue.boolean(bool value) = CustomBoolean;
  const factory CustomValue.number(BeanNumber value) = CustomNumber;
  const factory CustomValue.amount(Amount value) = CustomAmount;
}

@freezed
sealed class DirectiveBody with _$DirectiveBody {
  const factory DirectiveBody.transaction(ParsedTransaction value) = TransactionBody;
  const factory DirectiveBody.price({required Currency currency, required Amount amount}) = PriceBody;
  const factory DirectiveBody.balance({required Account account, required Amount amount, BeanNumber? tolerance}) =
      BalanceBody;
  const factory DirectiveBody.open({
    required Account account,
    @Default([]) List<Currency> currencies,
    BookingMethod? booking,
  }) = OpenBody;
  const factory DirectiveBody.close({required Account account}) = CloseBody;
  const factory DirectiveBody.commodity({required Currency currency}) = CommodityBody;
  const factory DirectiveBody.pad({required Account account, required Account sourceAccount}) = PadBody;
  const factory DirectiveBody.document({
    required Account account,
    required String filename,
    @Default([]) List<Tag> tags,
    @Default([]) List<Link> links,
  }) = DocumentBody;
  const factory DirectiveBody.note({
    required Account account,
    required String comment,
    @Default([]) List<Tag> tags,
    @Default([]) List<Link> links,
  }) = NoteBody;
  const factory DirectiveBody.event({required String name, required String description}) = EventBody;
  const factory DirectiveBody.query({required String name, required String queryString}) = QueryBody;
  const factory DirectiveBody.custom({required String type, @Default([]) List<CustomValue> values}) = CustomBody;
}

@freezed
abstract class ParsedDirective with _$ParsedDirective {
  const factory ParsedDirective({
    required BeanLocation location,
    required BeanDate date,
    @Default(Meta()) Meta meta,
    required DirectiveBody body,
  }) = _ParsedDirective;
}

@freezed
abstract class ParseError with _$ParseError {
  const factory ParseError({required String message, required BeanLocation location}) = _ParseError;
}
