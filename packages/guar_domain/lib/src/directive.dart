// Dated Beancount directives after booking and interpolation.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'amount.dart';
import 'date.dart';
import 'hash.dart';
import 'location.dart';
import 'meta.dart';
import 'origin.dart';
import 'transaction.dart';

part 'directive.freezed.dart';

enum BookingMethod { strict, strictWithSize, none, average, fifo, lifo, hifo }

@freezed
sealed class CustomValue with _$CustomValue {
  const factory CustomValue.text(String value) = CustomText;
  const factory CustomValue.account(Account value) = CustomAccount;
  const factory CustomValue.date(BeanDate value) = CustomDate;
  const factory CustomValue.boolean(bool value) = CustomBoolean;
  const factory CustomValue.number(Decimal value) = CustomNumber;
  const factory CustomValue.amount(Amount value) = CustomAmount;
}

@freezed
sealed class DirectiveBody with _$DirectiveBody {
  const factory DirectiveBody.transaction(Transaction value) = TransactionBody;
  const factory DirectiveBody.price({required Currency currency, required Amount amount}) = PriceBody;
  const factory DirectiveBody.balance({required Account account, required Amount amount, Decimal? tolerance}) =
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

@Freezed(copyWith: false, when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Directive with _$Directive {
  const Directive._();

  const factory Directive._create({
    required Origin origin,
    required BeanDate date,
    @Default(Meta()) Meta meta,
    required DirectiveBody body,
    required String hash,
  }) = _Directive;

  factory Directive({
    required Origin origin,
    required BeanDate date,
    Meta meta = const Meta(),
    required DirectiveBody body,
  }) {
    return Directive._create(origin: origin, date: date, meta: meta, body: body, hash: hashDirective(date, body));
  }

  Directive copyWith({Origin? origin, BeanDate? date, Meta? meta, DirectiveBody? body}) {
    return Directive(
      origin: origin ?? this.origin,
      date: date ?? this.date,
      meta: meta ?? this.meta,
      body: body ?? this.body,
    );
  }
}

@freezed
abstract class ProcessingError with _$ProcessingError {
  const factory ProcessingError({required String message, required BeanLocation location}) = _ProcessingError;
}
