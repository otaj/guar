// Dated Beancount directives after booking and interpolation.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/amount.dart';
import 'package:guar_domain/src/date.dart';
import 'package:guar_domain/src/hash.dart';
import 'package:guar_domain/src/location.dart';
import 'package:guar_domain/src/meta.dart';
import 'package:guar_domain/src/origin.dart';
import 'package:guar_domain/src/transaction.dart';

part 'directive.freezed.dart';

enum BookingMethod { strict, strictWithSize, none, average, fifo, lifo, hifo }

enum BudgetInterval { daily, weekly, monthly, quarterly, yearly }

@freezed
sealed class CustomValue with _$CustomValue {
  const factory CustomValue.text(String value) = CustomText;
  const factory CustomValue.account(Account value) = CustomAccount;
  const factory CustomValue.date(BeanDate value) = CustomDate;
  // ignore: avoid_positional_boolean_parameters, bool is the stored payload
  const factory CustomValue.boolean(bool value) = CustomBoolean;
  const factory CustomValue.number(Decimal value) = CustomNumber;
  const factory CustomValue.amount(Amount value) = CustomAmount;
  const factory CustomValue.currency(Currency value) = CustomCurrency;
}

@freezed
sealed class DirectiveBody with _$DirectiveBody {
  const factory DirectiveBody.transaction(Transaction value) = TransactionBody;
  const factory DirectiveBody.price({required Currency currency, required Amount amount}) = PriceBody;
  const factory DirectiveBody.balance({required Account account, required Amount amount, Decimal? tolerance}) =
      BalanceBody;
  const factory DirectiveBody.open({
    required Account account,
    @Default(<Currency>[]) List<Currency> currencies,
    BookingMethod? booking,
  }) = OpenBody;
  const factory DirectiveBody.close({required Account account}) = CloseBody;
  const factory DirectiveBody.commodity({required Currency currency}) = CommodityBody;
  const factory DirectiveBody.pad({required Account account, required Account sourceAccount}) = PadBody;
  const factory DirectiveBody.document({
    required Account account,
    required String filename,
    @Default(<Tag>[]) List<Tag> tags,
    @Default(<Link>[]) List<Link> links,
  }) = DocumentBody;
  const factory DirectiveBody.note({
    required Account account,
    required String comment,
    @Default(<Tag>[]) List<Tag> tags,
    @Default(<Link>[]) List<Link> links,
  }) = NoteBody;
  const factory DirectiveBody.event({required String name, required String description}) = EventBody;
  const factory DirectiveBody.query({required String name, required String queryString}) = QueryBody;
  const factory DirectiveBody.custom({required String type, @Default(<CustomValue>[]) List<CustomValue> values}) =
      CustomBody;
  const factory DirectiveBody.budget({
    required Account account,
    required BudgetInterval interval,
    required Amount amount,
  }) = BudgetBody;
  const factory DirectiveBody.budgetOff({required Account account, Currency? currency}) = BudgetOffBody;
}

@Freezed(copyWith: false, when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class Directive with _$Directive {
  factory Directive({
    required Origin origin,
    required BeanDate date,
    required DirectiveBody body,
    Meta meta = const Meta(),
  }) => Directive._create(origin: origin, date: date, meta: meta, body: body, hash: hashDirective(date, body));
  const Directive._();

  const factory Directive._create({
    required Origin origin,
    required BeanDate date,
    required DirectiveBody body,
    required String hash,
    @Default(Meta()) Meta meta,
  }) = _Directive;

  Directive copyWith({Origin? origin, BeanDate? date, Meta? meta, DirectiveBody? body}) => Directive(
    origin: origin ?? this.origin,
    date: date ?? this.date,
    meta: meta ?? this.meta,
    body: body ?? this.body,
  );
}

@freezed
abstract class ProcessingError with _$ProcessingError {
  const factory ProcessingError({required String message, required BeanLocation location}) = _ProcessingError;
}

@freezed
abstract class ProcessingWarning with _$ProcessingWarning {
  const factory ProcessingWarning({required String message, required BeanLocation location}) = _ProcessingWarning;
}
