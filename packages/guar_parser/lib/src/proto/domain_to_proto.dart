// Maps parser domain models onto protobean messages.

import 'package:guar_parser/guar_parser.dart' as domain;
import 'package:protobean/protobean.dart' as pb;

pb.ParsedLedger domainToProto(domain.ParsedLedger ledger) => switch (ledger) {
  domain.ParsedLedgerDirectives(
    :final List<domain.ParsedDirective> directives,
    :final domain.LedgerOptions options,
    :final domain.ProcessingInfo info,
  ) =>
    pb.ParsedLedger(
      directives: pb.ParsedDirectives(directives: directives.map(_directive).toList()),
      options: _options(options),
      info: _info(info),
    ),
  domain.ParsedLedgerErrors(
    :final List<domain.ParseError> errors,
    :final domain.LedgerOptions options,
    :final domain.ProcessingInfo info,
  ) =>
    pb.ParsedLedger(
      errors: pb.Errors(errors: errors.map(_error).toList()),
      options: _options(options),
      info: _info(info),
    ),
};

void clearLocations(pb.ParsedLedger ledger) {
  if (ledger.hasDirectives()) {
    clearDirectiveLocations(ledger.directives);
  }
  if (ledger.hasErrors()) {
    clearErrorLocations(ledger.errors);
  }
}

void clearDirectiveLocations(pb.ParsedDirectives directives) {
  for (final pb.ParsedDirective directive in directives.directives) {
    directive.clearLocation();
    if (directive.whichBody() == pb.ParsedDirective_Body.transaction) {
      for (final pb.ParsedPosting posting in directive.transaction.postings) {
        posting.clearLocation();
      }
    }
  }
}

void clearErrorLocations(pb.Errors errors) {
  for (final pb.Error error in errors.errors) {
    error.clearLocation();
  }
}

pb.Error _error(domain.ParseError error) => pb.Error(message: error.message, location: _location(error.location));

pb.ParsedDirective _directive(domain.ParsedDirective directive) {
  final pb.ParsedDirective message = pb.ParsedDirective(
    location: _location(directive.location),
    date: _date(directive.date),
    meta: directive.meta.entries.isEmpty ? null : _meta(directive.meta),
  );
  switch (directive.body) {
    case domain.TransactionBody(:final domain.ParsedTransaction value):
      message.transaction = _transaction(value);
    case domain.PriceBody(:final domain.Currency currency, :final domain.Amount amount):
      message.price = pb.Price(currency: _currency(currency), amount: _amount(amount));
    case domain.BalanceBody(
      :final domain.Account account,
      :final domain.Amount amount,
      :final domain.BeanNumber? tolerance,
    ):
      message.balance = pb.Balance(
        account: _account(account),
        amount: _amount(amount),
        tolerance: tolerance == null ? null : _number(tolerance),
      );
    case domain.OpenBody(
      :final domain.Account account,
      :final List<domain.Currency> currencies,
      :final domain.BookingMethod? booking,
    ):
      message.open = pb.Open(
        account: _account(account),
        currencies: currencies.map(_currency).toList(),
        booking: booking == null ? null : _booking(booking),
      );
    case domain.CloseBody(:final domain.Account account):
      message.close = pb.Close(account: _account(account));
    case domain.CommodityBody(:final domain.Currency currency):
      message.commodity = pb.Commodity(currency: _currency(currency));
    case domain.PadBody(:final domain.Account account, :final domain.Account sourceAccount):
      message.pad = pb.Pad(account: _account(account), sourceAccount: _account(sourceAccount));
    case domain.DocumentBody(
      :final domain.Account account,
      :final String filename,
      :final List<domain.Tag> tags,
      :final List<domain.Link> links,
    ):
      message.document = pb.Document(
        account: _account(account),
        filename: filename,
        tags: tags.map(_tag).toList(),
        links: links.map(_link).toList(),
      );
    case domain.NoteBody(
      :final domain.Account account,
      :final String comment,
      :final List<domain.Tag> tags,
      :final List<domain.Link> links,
    ):
      message.note = pb.Note(
        account: _account(account),
        comment: comment,
        tags: tags.map(_tag).toList(),
        links: links.map(_link).toList(),
      );
    case domain.EventBody(:final String name, :final String description):
      // Proto3 omits default empty strings; keep wire form aligned with goldens.
      message.event = pb.Event(name: name, description: description.isEmpty ? null : description);
    case domain.QueryBody(:final String name, :final String queryString):
      message.query = pb.Query(name: name, queryString: queryString);
    case domain.CustomBody(:final String type, :final List<domain.CustomValue> values):
      message.custom = pb.Custom(type: type, values: values.map(_customValue).toList());
  }
  return message;
}

pb.ParsedTransaction _transaction(domain.ParsedTransaction value) => pb.ParsedTransaction(
  flag: _flag(value.flag),
  payee: value.payee,
  narration: value.narration.isEmpty ? null : value.narration,
  tags: value.tags.map(_tag).toList(),
  links: value.links.map(_link).toList(),
  postings: value.postings.map(_posting).toList(),
);

pb.ParsedPosting _posting(domain.ParsedPosting posting) => pb.ParsedPosting(
  location: _location(posting.location),
  meta: posting.meta.entries.isEmpty ? null : _meta(posting.meta),
  flag: posting.flag == null ? null : _flag(posting.flag!),
  account: _account(posting.account),
  units: posting.units == null ? null : _incomplete(posting.units!),
  cost: posting.cost == null ? null : _cost(posting.cost!),
  price: posting.price == null ? null : _price(posting.price!),
);

pb.ParsedCost _cost(domain.ParsedCost cost) => pb.ParsedCost(
  numberPer: cost.numberPer == null ? null : _number(cost.numberPer!),
  numberTotal: cost.numberTotal == null ? null : _number(cost.numberTotal!),
  currency: cost.currency == null ? null : _currency(cost.currency!),
  date: cost.date == null ? null : _date(cost.date!),
  label: cost.label,
  merge: cost.merge ? true : null,
);

pb.ParsedPrice _price(domain.ParsedPrice price) => pb.ParsedPrice(
  number: price.number == null ? null : _number(price.number!),
  currency: price.currency == null ? null : _currency(price.currency!),
  isTotal: price.isTotal ? true : null,
);

pb.IncompleteAmount _incomplete(domain.IncompleteAmount amount) => pb.IncompleteAmount(
  number: amount.number == null ? null : _number(amount.number!),
  currency: amount.currency == null ? null : _currency(amount.currency!),
);

pb.Amount _amount(domain.Amount amount) =>
    pb.Amount(number: _number(amount.number), currency: _currency(amount.currency));

pb.Number _number(domain.BeanNumber number) => pb.Number(verbatim: number.verbatim, resolved: _resolvedString(number));

String _resolvedString(domain.BeanNumber number) {
  final String compact = number.verbatim.replaceAll(',', '').replaceAll(' ', '');
  if (RegExp(r'^[+-]?\d+(\.\d+)?$').hasMatch(compact)) {
    final int dot = compact.indexOf('.');
    if (dot >= 0) {
      return number.resolved.toStringAsFixed(compact.length - dot - 1);
    }
  }
  return number.resolved.toString();
}

pb.Date _date(domain.BeanDate date) => pb.Date(year: date.year, month: date.month, day: date.day);

pb.Location _location(domain.BeanLocation location) =>
    pb.Location(filename: location.filename, linenoBegin: location.linenoBegin, linenoEnd: location.linenoEnd);

pb.Account _account(domain.Account account) => pb.Account(name: account.name);

pb.Currency _currency(domain.Currency currency) => pb.Currency(name: currency.name);

pb.Tag _tag(domain.Tag tag) => pb.Tag(name: tag.name);

pb.Link _link(domain.Link link) => pb.Link(name: link.name);

pb.Flag _flag(domain.Flag flag) => switch (flag) {
  domain.SpecialFlagValue(:final domain.SpecialFlag value) => pb.Flag(special: _special(value)),
  domain.LetterFlag(:final String value) => pb.Flag(letter: value),
};

pb.SpecialFlag _special(domain.SpecialFlag flag) => switch (flag) {
  domain.SpecialFlag.asterisk => pb.SpecialFlag.SPECIAL_FLAG_ASTERISK,
  domain.SpecialFlag.exclamation => pb.SpecialFlag.SPECIAL_FLAG_EXCLAMATION,
  domain.SpecialFlag.hash => pb.SpecialFlag.SPECIAL_FLAG_HASH,
  domain.SpecialFlag.ampersand => pb.SpecialFlag.SPECIAL_FLAG_AMPERSAND,
  domain.SpecialFlag.question => pb.SpecialFlag.SPECIAL_FLAG_QUESTION,
  domain.SpecialFlag.percent => pb.SpecialFlag.SPECIAL_FLAG_PERCENT,
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

pb.Meta _meta(domain.Meta meta) => pb.Meta(
  entries: meta.entries
      // Proto3 omits default empty keys; keep wire form aligned with goldens.
      .map(
        (domain.MetaEntry entry) => pb.Meta_Entry(
          key: entry.key.isEmpty ? null : entry.key,
          value: entry.value == null ? null : _metaValue(entry.value!),
        ),
      )
      .toList(),
);

pb.MetaValue _metaValue(domain.MetaValue value) => switch (value) {
  domain.MetaText(:final String value) => pb.MetaValue(text: value),
  domain.MetaAccount(:final domain.Account value) => pb.MetaValue(account: _account(value)),
  domain.MetaCurrency(:final domain.Currency value) => pb.MetaValue(currency: _currency(value)),
  domain.MetaTag(:final domain.Tag value) => pb.MetaValue(tag: _tag(value)),
  domain.MetaDate(:final domain.BeanDate value) => pb.MetaValue(date: _date(value)),
  domain.MetaBoolean(:final bool value) => pb.MetaValue(boolean: value),
  domain.MetaNumber(:final domain.BeanNumber value) => pb.MetaValue(number: _number(value)),
  domain.MetaAmount(:final domain.Amount value) => pb.MetaValue(amount: _amount(value)),
};

pb.CustomValue _customValue(domain.CustomValue value) => switch (value) {
  domain.CustomText(:final String value) => pb.CustomValue(text: value),
  domain.CustomAccount(:final domain.Account value) => pb.CustomValue(account: _account(value)),
  domain.CustomDate(:final domain.BeanDate value) => pb.CustomValue(date: _date(value)),
  domain.CustomBoolean(:final bool value) => pb.CustomValue(boolean: value),
  domain.CustomNumber(:final domain.BeanNumber value) => pb.CustomValue(number: _number(value)),
  domain.CustomAmount(:final domain.Amount value) => pb.CustomValue(amount: _amount(value)),
  domain.CustomCurrency(:final domain.Currency value) => pb.CustomValue(text: value.name),
};

pb.Options _options(domain.LedgerOptions options) => pb.Options(
  accountPrefixes: _accountPrefixes(options.accountPrefixes),
  title: options.title,
  accountPreviousBalances: switch (options.accountPreviousBalances) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountPreviousEarnings: switch (options.accountPreviousEarnings) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountPreviousConversions: switch (options.accountPreviousConversions) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountCurrentEarnings: switch (options.accountCurrentEarnings) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountCurrentConversions: switch (options.accountCurrentConversions) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountUnrealizedGains: switch (options.accountUnrealizedGains) {
    null => null,
    final domain.Account account => _account(account),
  },
  accountRounding: switch (options.accountRounding) {
    null => null,
    final domain.Account account => _account(account),
  },
  conversionCurrency: switch (options.conversionCurrency) {
    null => null,
    final domain.Currency currency => _currency(currency),
  },
  displayPrecision: options.displayPrecision.map(_displayPrecision).toList(),
  inferredToleranceDefault: options.inferredToleranceDefault.map(_inferredTolerance).toList(),
  toleranceMultiplier: switch (options.toleranceMultiplier) {
    null => null,
    final domain.BeanNumber number => _number(number),
  },
  inferToleranceFromCost: options.inferToleranceFromCost,
  documents: options.documents,
  operatingCurrency: options.operatingCurrency.map(_currency).toList(),
  renderCommas: options.renderCommas,
  pluginProcessingMode: switch (options.pluginProcessingMode) {
    null => null,
    domain.PluginProcessingMode.defaultMode => pb.PluginProcessingMode.PLUGIN_PROCESSING_MODE_DEFAULT,
    domain.PluginProcessingMode.raw => pb.PluginProcessingMode.PLUGIN_PROCESSING_MODE_RAW,
  },
  longStringMaxlines: options.longStringMaxlines,
  bookingMethod: switch (options.bookingMethod) {
    null => null,
    final domain.BookingMethod method => _booking(method),
  },
  usePreciseInterpolation: options.usePreciseInterpolation,
  insertPythonpath: options.insertPythonpath,
  allowPipeSeparator: options.allowPipeSeparator,
  allowDeprecatedNoneForTagsAndLinks: options.allowDeprecatedNoneForTagsAndLinks,
);

pb.AccountPrefixes? _accountPrefixes(domain.AccountPrefixes prefixes) {
  if (prefixes.assets == null &&
      prefixes.liabilities == null &&
      prefixes.equity == null &&
      prefixes.income == null &&
      prefixes.expenses == null) {
    return null;
  }
  return pb.AccountPrefixes(
    assets: prefixes.assets,
    liabilities: prefixes.liabilities,
    equity: prefixes.equity,
    income: prefixes.income,
    expenses: prefixes.expenses,
  );
}

pb.DisplayPrecision _displayPrecision(domain.DisplayPrecision value) =>
    pb.DisplayPrecision(key: _displayPrecisionKey(value.key), value: _number(value.value));

pb.DisplayPrecisionKey _displayPrecisionKey(domain.DisplayPrecisionKey key) => switch (key) {
  domain.DisplayPrecisionCurrency(:final domain.Currency value) => pb.DisplayPrecisionKey(currency: _currency(value)),
  domain.DisplayPrecisionAll() => pb.DisplayPrecisionKey(all: pb.AllCurrencies()),
  domain.DisplayPrecisionPair(:final domain.Currency first, :final domain.Currency second) => pb.DisplayPrecisionKey(
    pair: pb.CurrencyPair(first: _currency(first), second: _currency(second)),
  ),
};

pb.InferredTolerance _inferredTolerance(domain.InferredTolerance value) =>
    pb.InferredTolerance(key: _currencyKey(value.key), value: _number(value.value));

pb.CurrencyKey _currencyKey(domain.CurrencyKey key) => switch (key) {
  domain.CurrencyKeyCurrency(:final domain.Currency value) => pb.CurrencyKey(currency: _currency(value)),
  domain.CurrencyKeyAll() => pb.CurrencyKey(all: pb.AllCurrencies()),
};

pb.ProcessingInfo _info(domain.ProcessingInfo info) => pb.ProcessingInfo(
  filename: info.filename,
  include: info.include,
  commodities: info.commodities.map(_currency).toList(),
  plugin: info.plugin.map((domain.Plugin plugin) => pb.Plugin(name: plugin.name, config: plugin.config)).toList(),
  displayContext: pb.DisplayContext(precisions: info.displayContext.precisions.map(_displayPrecision).toList()),
);
