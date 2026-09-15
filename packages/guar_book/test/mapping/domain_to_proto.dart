// Maps booked domain models onto protobean Processed* messages for goldens.

import 'package:guar_domain/guar_domain.dart' as domain;
import 'package:protobean/protobean.dart' as pb;

pb.ProcessedLedger ledgerToProto(domain.Ledger ledger) {
  return switch (ledger) {
    domain.LedgerDirectives(:final directives, :final options, :final info) => pb.ProcessedLedger(
      directives: pb.ProcessedDirectives(directives: directives.map(_directive).toList()),
      options: _options(options),
      info: _info(info),
    ),
    domain.LedgerErrors(:final errors, :final options, :final info) => pb.ProcessedLedger(
      errors: pb.Errors(errors: errors.map(_error).toList()),
      options: _options(options),
      info: _info(info),
    ),
  };
}

void clearProcessedDirectiveLocations(pb.ProcessedDirectives directives) {
  for (final directive in directives.directives) {
    directive.clearLocation();
    if (directive.whichBody() == pb.ProcessedDirective_Body.transaction) {
      directive.transaction.clearLocation();
      for (final posting in directive.transaction.postings) {
        posting.clearLocation();
      }
    }
  }
}

void clearErrorLocations(pb.Errors errors) {
  for (final error in errors.errors) {
    error.clearLocation();
  }
}

pb.Error _error(domain.ProcessingError error) => pb.Error(message: error.message, location: _location(error.location));

pb.ProcessedDirective _directive(domain.Directive directive) {
  final message = pb.ProcessedDirective(
    date: _date(directive.date),
    meta: directive.meta.entries.isEmpty ? null : _meta(directive.meta),
  );
  switch (directive.origin) {
    case domain.SourceOrigin(:final location):
      message.location = _location(location);
    case domain.GeneratedOrigin():
      break;
  }
  switch (directive.body) {
    case domain.TransactionBody(:final value):
      message.transaction = _transaction(value);
    case domain.PriceBody(:final currency, :final amount):
      message.price = pb.ProcessedPrice(currency: _currency(currency), amount: _amount(amount));
    case domain.BalanceBody(:final account, :final amount, :final tolerance):
      message.balance = pb.ProcessedBalance(
        account: _account(account),
        amount: _amount(amount),
        tolerance: tolerance == null ? null : _decimal(tolerance),
      );
    case domain.OpenBody(:final account, :final currencies, :final booking):
      message.open = pb.Open(
        account: _account(account),
        currencies: currencies.map(_currency).toList(),
        booking: booking == null ? null : _booking(booking),
      );
    case domain.CloseBody(:final account):
      message.close = pb.Close(account: _account(account));
    case domain.CommodityBody(:final currency):
      message.commodity = pb.Commodity(currency: _currency(currency));
    case domain.PadBody(:final account, :final sourceAccount):
      message.pad = pb.Pad(account: _account(account), sourceAccount: _account(sourceAccount));
    case domain.DocumentBody(:final account, :final filename, :final tags, :final links):
      message.document = pb.Document(
        account: _account(account),
        filename: filename,
        tags: tags.map(_tag).toList(),
        links: links.map(_link).toList(),
      );
    case domain.NoteBody(:final account, :final comment, :final tags, :final links):
      message.note = pb.Note(
        account: _account(account),
        comment: comment,
        tags: tags.map(_tag).toList(),
        links: links.map(_link).toList(),
      );
    case domain.EventBody(:final name, :final description):
      message.event = pb.Event(name: name, description: description.isEmpty ? null : description);
    case domain.QueryBody(:final name, :final queryString):
      message.query = pb.Query(name: name, queryString: queryString);
    case domain.CustomBody(:final type, :final values):
      message.custom = pb.ProcessedCustom(type: type, values: values.map(_customValue).toList());
  }
  return message;
}

pb.ProcessedTransaction _transaction(domain.Transaction txn) {
  final message = pb.ProcessedTransaction(
    flag: _flag(txn.flag),
    payee: txn.payee,
    narration: txn.narration.isEmpty ? null : txn.narration,
    tags: txn.tags.map(_tag).toList(),
    links: txn.links.map(_link).toList(),
    postings: txn.postings.map(_posting).toList(),
  );
  switch (txn.origin) {
    case domain.SourceOrigin(:final location):
      message.location = _location(location);
    case domain.GeneratedOrigin():
      break;
  }
  return message;
}

pb.ProcessedPosting _posting(domain.Posting posting) {
  final message = pb.ProcessedPosting(
    meta: posting.meta.entries.isEmpty ? null : _meta(posting.meta),
    flag: posting.flag == null ? null : _flag(posting.flag!),
    account: _account(posting.account),
    units: _amount(posting.units),
    cost: posting.cost == null ? null : _cost(posting.cost!),
    price: posting.price == null ? null : _amount(posting.price!),
  );
  switch (posting.origin) {
    case domain.SourceOrigin(:final location):
      message.location = _location(location);
    case domain.GeneratedOrigin():
      break;
  }
  return message;
}

pb.ProcessedCost _cost(domain.Cost cost) => pb.ProcessedCost(
  number: _decimal(cost.number),
  currency: _currency(cost.currency),
  date: _date(cost.date),
  label: cost.label,
);

pb.ProcessedAmount _amount(domain.Amount amount) =>
    pb.ProcessedAmount(number: _decimal(amount.number), currency: _currency(amount.currency));

pb.ProcessedMeta _meta(domain.Meta meta) => pb.ProcessedMeta(
  entries: [
    for (final entry in meta.entries)
      pb.ProcessedMeta_Entry(key: entry.key, value: entry.value == null ? null : _metaValue(entry.value!)),
  ],
);

pb.ProcessedMetaValue _metaValue(domain.MetaValue value) {
  final message = pb.ProcessedMetaValue();
  switch (value) {
    case domain.MetaText(:final value):
      message.text = value;
    case domain.MetaAccount(:final value):
      message.account = _account(value);
    case domain.MetaCurrency(:final value):
      message.currency = _currency(value);
    case domain.MetaTag(:final value):
      message.tag = _tag(value);
    case domain.MetaDate(:final value):
      message.date = _date(value);
    case domain.MetaBoolean(:final value):
      message.boolean = value;
    case domain.MetaNumber(:final value):
      message.number = _decimal(value);
    case domain.MetaAmount(:final value):
      message.amount = _amount(value);
  }
  return message;
}

pb.ProcessedCustomValue _customValue(domain.CustomValue value) {
  final message = pb.ProcessedCustomValue();
  switch (value) {
    case domain.CustomText(:final value):
      message.text = value;
    case domain.CustomAccount(:final value):
      message.account = _account(value);
    case domain.CustomDate(:final value):
      message.date = _date(value);
    case domain.CustomBoolean(:final value):
      message.boolean = value;
    case domain.CustomNumber(:final value):
      message.number = _decimal(value);
    case domain.CustomAmount(:final value):
      message.amount = _amount(value);
  }
  return message;
}

pb.Options _options(domain.LedgerOptions options) {
  // Goldens compare directives/errors only; options are asserted in unit tests.
  return pb.Options();
}

pb.ProcessingInfo _info(domain.ProcessingInfo info) => pb.ProcessingInfo();

pb.Location _location(domain.BeanLocation location) => pb.Location(
  filename: location.filename.isEmpty ? null : location.filename,
  linenoBegin: location.linenoBegin,
  linenoEnd: location.linenoEnd,
);

pb.Date _date(domain.BeanDate date) => pb.Date(year: date.year, month: date.month, day: date.day);

pb.Account _account(domain.Account account) => pb.Account(name: account.name);

pb.Currency _currency(domain.Currency currency) => pb.Currency(name: currency.name);

pb.Tag _tag(domain.Tag tag) => pb.Tag(name: tag.name);

pb.Link _link(domain.Link link) => pb.Link(name: link.name);

pb.Decimal _decimal(Object number) => pb.Decimal(value: number.toString());

pb.Flag _flag(domain.Flag flag) => switch (flag) {
  domain.SpecialFlagValue(:final value) => pb.Flag(
    special: switch (value) {
      domain.SpecialFlag.asterisk => pb.SpecialFlag.SPECIAL_FLAG_ASTERISK,
      domain.SpecialFlag.exclamation => pb.SpecialFlag.SPECIAL_FLAG_EXCLAMATION,
      domain.SpecialFlag.hash => pb.SpecialFlag.SPECIAL_FLAG_HASH,
      domain.SpecialFlag.ampersand => pb.SpecialFlag.SPECIAL_FLAG_AMPERSAND,
      domain.SpecialFlag.question => pb.SpecialFlag.SPECIAL_FLAG_QUESTION,
      domain.SpecialFlag.percent => pb.SpecialFlag.SPECIAL_FLAG_PERCENT,
    },
  ),
  domain.LetterFlag(:final value) => pb.Flag(letter: value),
};

pb.Booking _booking(domain.BookingMethod method) => switch (method) {
  domain.BookingMethod.strict => pb.Booking.BOOKING_STRICT,
  domain.BookingMethod.strictWithSize => pb.Booking.BOOKING_STRICT_WITH_SIZE,
  domain.BookingMethod.none => pb.Booking.BOOKING_NONE,
  domain.BookingMethod.average => pb.Booking.BOOKING_AVERAGE,
  domain.BookingMethod.fifo => pb.Booking.BOOKING_FIFO,
  domain.BookingMethod.lifo => pb.Booking.BOOKING_LIFO,
  domain.BookingMethod.hifo => pb.Booking.BOOKING_HIFO,
};
