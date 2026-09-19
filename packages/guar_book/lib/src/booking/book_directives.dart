// Lot matching and interpolation of parsed transactions into booked directives.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/booking/interpolate.dart';
import 'package:guar_book/src/map/primitives.dart';
import 'package:guar_book/src/options_defaults.dart';
import 'package:guar_book/src/stage_result.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

StageResult bookDirectives({required List<p.ParsedDirective> parsed, required d.LedgerOptions options}) {
  final Map<String, d.Inventory> balances = <String, d.Inventory>{};
  final Map<String, d.BookingMethod> methods = <String, d.BookingMethod>{};
  final d.BookingMethod defaultMethod = options.bookingMethod;
  final List<d.Directive> out = <d.Directive>[];
  final List<d.ProcessingError> errors = <d.ProcessingError>[];

  for (final p.ParsedDirective directive in parsed) {
    final p.DirectiveBody body = directive.body;
    if (body is p.OpenBody && body.booking != null) {
      methods[body.account.name] = mapBookingMethod(body.booking)!;
    }

    if (body is! p.TransactionBody) {
      final d.Directive? mapped = mapNonTransaction(directive, options.accountPrefixes);
      if (mapped != null) {
        out.add(mapped);
      }
      continue;
    }

    final ({d.Directive? directive, List<d.ProcessingError> errors}) booked = _bookTransaction(
      directive: directive,
      transaction: body.value,
      balances: balances,
      methods: methods,
      defaultMethod: defaultMethod,
      options: options,
    );
    if (booked.errors.isNotEmpty) {
      errors.addAll(booked.errors);
      continue;
    }
    out.add(booked.directive!);
  }

  return StageResult(directives: out, errors: errors);
}

d.Directive? mapNonTransaction(p.ParsedDirective directive, d.AccountPrefixes prefixes) {
  final d.Origin origin = sourceOrigin(directive.location);
  final d.BeanDate date = mapDate(directive.date);
  final d.Meta meta = mapMeta(directive.meta, prefixes);
  final d.DirectiveBody? body = switch (directive.body) {
    p.PriceBody(:final p.Currency currency, :final p.Amount amount) => d.DirectiveBody.price(
      currency: d.Currency(name: currency.name),
      amount: mapAmount(amount),
    ),
    p.BalanceBody(:final p.Account account, :final p.Amount amount, :final p.BeanNumber? tolerance) =>
      d.DirectiveBody.balance(
        account: domainAccount(account.name, prefixes),
        amount: mapAmount(amount),
        tolerance: tolerance?.resolved,
      ),
    p.OpenBody(:final p.Account account, :final List<p.Currency> currencies, :final p.BookingMethod? booking) =>
      d.DirectiveBody.open(
        account: domainAccount(account.name, prefixes),
        currencies: <d.Currency>[for (final p.Currency currency in currencies) d.Currency(name: currency.name)],
        booking: mapBookingMethod(booking),
      ),
    p.CloseBody(:final p.Account account) => d.DirectiveBody.close(account: domainAccount(account.name, prefixes)),
    p.CommodityBody(:final p.Currency currency) => d.DirectiveBody.commodity(currency: d.Currency(name: currency.name)),
    p.PadBody(:final p.Account account, :final p.Account sourceAccount) => d.DirectiveBody.pad(
      account: domainAccount(account.name, prefixes),
      sourceAccount: domainAccount(sourceAccount.name, prefixes),
    ),
    p.DocumentBody(
      :final p.Account account,
      :final String filename,
      :final List<p.Tag> tags,
      :final List<p.Link> links,
    ) =>
      d.DirectiveBody.document(
        account: domainAccount(account.name, prefixes),
        filename: filename,
        tags: <d.Tag>[for (final p.Tag tag in tags) d.Tag(name: tag.name)],
        links: <d.Link>[for (final p.Link link in links) d.Link(name: link.name)],
      ),
    p.NoteBody(:final p.Account account, :final String comment, :final List<p.Tag> tags, :final List<p.Link> links) =>
      d.DirectiveBody.note(
        account: domainAccount(account.name, prefixes),
        comment: comment,
        tags: <d.Tag>[for (final p.Tag tag in tags) d.Tag(name: tag.name)],
        links: <d.Link>[for (final p.Link link in links) d.Link(name: link.name)],
      ),
    p.EventBody(:final String name, :final String description) => d.DirectiveBody.event(
      name: name,
      description: description,
    ),
    p.QueryBody(:final String name, :final String queryString) => d.DirectiveBody.query(
      name: name,
      queryString: queryString,
    ),
    p.CustomBody(:final String type, :final List<p.CustomValue> values) => _mapCustom(type, values, prefixes),
    p.TransactionBody() => null,
  };
  if (body == null) {
    return null;
  }
  return d.Directive(origin: origin, date: date, meta: meta, body: body);
}

({d.Directive? directive, List<d.ProcessingError> errors}) _bookTransaction({
  required p.ParsedDirective directive,
  required p.ParsedTransaction transaction,
  required Map<String, d.Inventory> balances,
  required Map<String, d.BookingMethod> methods,
  required d.BookingMethod defaultMethod,
  required d.LedgerOptions options,
}) {
  final d.AccountPrefixes prefixes = options.accountPrefixes;
  final d.BeanLocation location = mapLocation(directive.location);
  final d.BeanDate date = mapDate(directive.date);
  final d.Origin origin = sourceOrigin(directive.location);
  final List<MutablePosting> mutable = <MutablePosting>[];

  for (final p.ParsedPosting posting in transaction.postings) {
    final d.Account account = domainAccount(posting.account.name, prefixes);
    final d.Amount? units = mapCompleteUnits(posting.units);
    final Decimal? unitsAbs = units?.number.abs();
    final d.Cost? resolvedCost = units == null ? null : mapResolvedCost(posting.cost, date, unitsAbs!);
    PendingCost? pending;
    if (posting.cost != null && resolvedCost == null) {
      pending = PendingCost(
        numberPer: posting.cost!.numberPer?.resolved,
        numberTotal: posting.cost!.numberTotal?.resolved,
        currency: posting.cost!.currency == null ? null : d.Currency(name: posting.cost!.currency!.name),
        date: posting.cost!.date == null
            ? date
            : d.BeanDate(
                year: posting.cost!.date!.year,
                month: posting.cost!.date!.month,
                day: posting.cost!.date!.day,
              ),
        label: posting.cost!.label,
      );
    }
    final d.Amount? price = mapPrice(posting.price, unitsAbs);
    mutable.add(
      MutablePosting(
        origin: sourceOrigin(posting.location),
        meta: mapMeta(posting.meta, prefixes),
        flag: posting.flag == null ? null : mapFlag(posting.flag!),
        account: account,
        units: units,
        cost: resolvedCost,
        pendingCost: pending,
        price: price,
      ),
    );
  }

  // Book reductions against ante-inventory.
  final List<MutablePosting> booked = <MutablePosting>[];
  final List<d.ProcessingError> errors = <d.ProcessingError>[];
  for (final MutablePosting posting in mutable) {
    final d.Amount? units = posting.units;
    final d.BookingMethod method = methods[posting.account.name] ?? defaultMethod;
    final d.Inventory balance = balances[posting.account.name] ?? const d.Inventory();
    final bool isReduction =
        units != null &&
        (posting.cost != null || posting.pendingCost != null) &&
        method != d.BookingMethod.none &&
        _isReducedBy(balance, units);

    if (!isReduction) {
      booked.add(posting);
      continue;
    }

    final List<d.Position> matches = _matchLots(
      balance,
      units,
      posting.cost ?? posting.pendingCost?.toCost(units.number.abs()),
    );
    if (matches.isEmpty) {
      errors.add(
        d.ProcessingError(
          message: 'No position matches "${posting.account.name}" against balance $balance',
          location: location,
        ),
      );
      return (directive: null, errors: errors);
    }

    final ({List<d.ProcessingError> errors, List<MutablePosting> postings}) reduced = _applyMethod(
      method,
      posting,
      matches,
      location,
    );
    if (reduced.errors.isNotEmpty) {
      return (directive: null, errors: reduced.errors);
    }
    booked.addAll(reduced.postings);
  }

  final InferredTolerances tolerancesMax = inferTolerances(booked, options);
  final InferredTolerances tolerancesInterp = options.usePreciseInterpolation
      ? inferTolerances(booked, options, mode: ToleranceMode.min)
      : tolerancesMax;

  final ({List<d.ProcessingError> errors, List<MutablePosting> postings}) interpolated = interpolateGroup(
    booked,
    location,
    tolerancesInterp,
  );
  if (interpolated.errors.isNotEmpty) {
    return (directive: null, errors: interpolated.errors);
  }
  final d.Account? rounding = options.accountRounding;
  if (rounding != null) {
    fillResidualPostings(interpolated.postings, rounding);
  }

  for (final MutablePosting posting in interpolated.postings) {
    if (posting.units != null &&
        posting.units!.number == Decimal.zero &&
        (posting.cost != null || posting.pendingCost != null)) {
      return (
        directive: null,
        errors: <d.ProcessingError>[d.ProcessingError(message: 'Amount is zero', location: location)],
      );
    }
  }

  final List<d.Posting> postings = <d.Posting>[];
  for (final MutablePosting posting in interpolated.postings) {
    try {
      postings.add(posting.toPosting());
    } on Object catch (_) {
      return (
        directive: null,
        errors: <d.ProcessingError>[
          d.ProcessingError(message: 'Transaction has incomplete elements', location: location),
        ],
      );
    }
  }

  for (final d.Posting posting in postings) {
    final d.Inventory current = balances[posting.account.name] ?? const d.Inventory();
    balances[posting.account.name] = current
        .addPosition(d.Position(units: posting.units, cost: posting.cost))
        .inventory;
  }

  return (
    directive: d.Directive(
      origin: origin,
      date: date,
      meta: mapMeta(directive.meta, prefixes),
      body: d.DirectiveBody.transaction(
        d.Transaction(
          origin: origin,
          flag: mapFlag(transaction.flag),
          payee: transaction.payee,
          narration: transaction.narration,
          tags: <d.Tag>[for (final p.Tag tag in transaction.tags) d.Tag(name: tag.name)],
          links: <d.Link>[for (final p.Link link in transaction.links) d.Link(name: link.name)],
          postings: postings,
        ),
      ),
    ),
    errors: const <d.ProcessingError>[],
  );
}

bool _isReducedBy(d.Inventory balance, d.Amount units) {
  for (final d.Position position in balance.positions) {
    if (position.units.currency == units.currency &&
        ((position.units.number > Decimal.zero) != (units.number > Decimal.zero)) &&
        position.units.number != Decimal.zero &&
        units.number != Decimal.zero) {
      return true;
    }
  }
  return false;
}

List<d.Position> _matchLots(d.Inventory balance, d.Amount units, d.Cost? costHint) {
  final List<d.Position> matches = <d.Position>[];
  for (final d.Position position in balance.positions) {
    if (position.units.currency != units.currency) continue;
    if (position.cost == null) continue;
    if (costHint != null) {
      if (position.cost!.currency != costHint.currency) continue;
      if (position.cost!.number != costHint.number) continue;
      if (costHint.label != null && position.cost!.label != costHint.label) continue;
    }
    matches.add(position);
  }
  return matches;
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyMethod(
  d.BookingMethod method,
  MutablePosting posting,
  List<d.Position> matches,
  d.BeanLocation location,
) {
  switch (method) {
    case d.BookingMethod.strict:
      return _applyStrict(posting, matches, location, withSize: false);
    case d.BookingMethod.strictWithSize:
      return _applyStrict(posting, matches, location, withSize: true);
    case d.BookingMethod.fifo:
    case d.BookingMethod.lifo:
    case d.BookingMethod.hifo:
      final List<d.Position> ordered = <d.Position>[...matches]
        ..sort((d.Position a, d.Position b) {
          if (method == d.BookingMethod.hifo) {
            return -a.cost!.number.compareTo(b.cost!.number);
          }
          final int byDate = d.compareBeanDate(a.cost!.date, b.cost!.date);
          return method == d.BookingMethod.lifo ? -byDate : byDate;
        });
      return _applyXifo(posting, ordered, location);
    case d.BookingMethod.none:
      return (postings: <MutablePosting>[posting], errors: const <d.ProcessingError>[]);
    case d.BookingMethod.average:
      return _applyAverage(posting, matches, location);
  }
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyAverage(
  MutablePosting posting,
  List<d.Position> matches,
  d.BeanLocation location,
) {
  final d.Amount units = posting.units!;
  final bool hasExplicitCost =
      posting.cost != null ||
      (posting.pendingCost != null &&
          (posting.pendingCost!.numberPer != null || posting.pendingCost!.numberTotal != null));

  if (matches.length == 1 && !hasExplicitCost) {
    final d.Position match = matches.single;
    final Decimal sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
    final Decimal take = match.units.number.abs() < units.number.abs() ? match.units.number.abs() : units.number.abs();
    if (take != units.number.abs()) {
      return (
        postings: const <MutablePosting>[],
        errors: <d.ProcessingError>[d.ProcessingError(message: 'Not enough lots to reduce', location: location)],
      );
    }
    return (
      postings: <MutablePosting>[
        MutablePosting(
          origin: posting.origin,
          meta: posting.meta,
          flag: posting.flag,
          account: posting.account,
          units: d.Amount(number: take * sign, currency: units.currency),
          cost: match.cost,
          price: posting.price,
        ),
      ],
      errors: const <d.ProcessingError>[],
    );
  }

  Decimal totalUnits = Decimal.zero;
  Decimal totalCost = Decimal.zero;
  final Set<String> unitCurrencies = <String>{};
  final Set<String> costCurrencies = <String>{};
  for (final d.Position match in matches) {
    unitCurrencies.add(match.units.currency.name);
    costCurrencies.add(match.cost!.currency.name);
    totalUnits += match.units.number;
    totalCost += match.units.number * match.cost!.number;
  }
  if (unitCurrencies.length != 1 || costCurrencies.length != 1) {
    final String detail = matches.map(_positionString).join(', ');
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[
        d.ProcessingError(message: 'Cannot merge positions in multiple currencies: $detail', location: location),
      ],
    );
  }
  if (hasExplicitCost) {
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[
        d.ProcessingError(
          message: "Explicit cost reductions aren't supported yet: ${_postingString(posting)}",
          location: location,
        ),
      ],
    );
  }
  if (units.number.abs() > totalUnits.abs()) {
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[d.ProcessingError(message: 'Not enough lots to reduce', location: location)],
    );
  }

  final d.Flag mergeFlag = d.Flag.letter('M');
  final d.Cost avgCost = d.Cost(
    number: (totalCost / totalUnits).toDecimal(scaleOnInfinitePrecision: 28),
    currency: matches.first.cost!.currency,
    date: matches.first.cost!.date,
  );
  final List<MutablePosting> out = <MutablePosting>[
    for (final d.Position match in matches)
      MutablePosting(
        origin: posting.origin,
        meta: posting.meta,
        flag: mergeFlag,
        account: posting.account,
        units: d.Amount(number: -match.units.number, currency: match.units.currency),
        cost: match.cost,
        price: posting.price,
      ),
    MutablePosting(
      origin: posting.origin,
      meta: posting.meta,
      flag: mergeFlag,
      account: posting.account,
      units: d.Amount(number: totalUnits, currency: units.currency),
      cost: avgCost,
      price: posting.price,
    ),
    MutablePosting(
      origin: posting.origin,
      meta: posting.meta,
      flag: posting.flag,
      account: posting.account,
      units: units,
      cost: avgCost,
      price: posting.price,
    ),
  ];
  return (postings: out, errors: const <d.ProcessingError>[]);
}

String _positionString(d.Position position) {
  final d.Cost? cost = position.cost;
  if (cost == null) {
    return '${position.units.number} ${position.units.currency.name}';
  }
  final String date = '${cost.date}';
  final String label = cost.label == null ? '' : ' "${cost.label}"';
  return '${position.units.number} ${position.units.currency.name} {${cost.number} ${cost.currency.name}, $date$label}';
}

String _postingString(MutablePosting posting) {
  final d.Amount? units = posting.units;
  if (units == null) {
    return posting.account.name;
  }
  final d.Cost? cost = posting.cost ?? posting.pendingCost?.toCost(units.number.abs());
  if (cost == null) {
    final PendingCost? pending = posting.pendingCost;
    if (pending == null) {
      return '${units.number} ${units.currency.name}';
    }
    return '${units.number} ${units.currency.name} {}';
  }
  return _positionString(d.Position(units: units, cost: cost));
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyStrict(
  MutablePosting posting,
  List<d.Position> matches,
  d.BeanLocation location, {
  required bool withSize,
}) {
  final d.Amount units = posting.units!;
  if (matches.length > 1) {
    final Decimal sumMatches = matches.fold<Decimal>(
      Decimal.zero,
      (Decimal sum, d.Position match) => sum + match.units.number,
    );
    if (sumMatches == -units.number) {
      return (
        postings: <MutablePosting>[
          for (final d.Position match in matches)
            MutablePosting(
              origin: posting.origin,
              meta: posting.meta,
              flag: posting.flag,
              account: posting.account,
              units: d.Amount(number: -match.units.number, currency: match.units.currency),
              cost: match.cost,
              price: posting.price,
            ),
        ],
        errors: const <d.ProcessingError>[],
      );
    }
    if (withSize) {
      final Decimal want = -units.number;
      final List<d.Position> sized = matches.where((d.Position match) => match.units.number == want).toList()
        ..sort((d.Position a, d.Position b) => d.compareBeanDate(a.cost!.date, b.cost!.date));
      if (sized.isNotEmpty) {
        final d.Position match = sized.first;
        return (
          postings: <MutablePosting>[
            MutablePosting(
              origin: posting.origin,
              meta: posting.meta,
              flag: posting.flag,
              account: posting.account,
              units: units,
              cost: match.cost,
              price: posting.price,
            ),
          ],
          errors: const <d.ProcessingError>[],
        );
      }
    }
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[
        d.ProcessingError(
          message: 'Ambiguous matches for inventory reduction: ${matches.length} matching lots',
          location: location,
        ),
      ],
    );
  }
  final d.Position match = matches.single;
  final Decimal sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
  final Decimal take = match.units.number.abs() < units.number.abs() ? match.units.number.abs() : units.number.abs();
  if (take != units.number.abs()) {
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[d.ProcessingError(message: 'Not enough lots to reduce', location: location)],
    );
  }
  return (
    postings: <MutablePosting>[
      MutablePosting(
        origin: posting.origin,
        meta: posting.meta,
        flag: posting.flag,
        account: posting.account,
        units: d.Amount(number: take * sign, currency: units.currency),
        cost: match.cost,
        price: posting.price,
      ),
    ],
    errors: const <d.ProcessingError>[],
  );
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyXifo(
  MutablePosting posting,
  List<d.Position> ordered,
  d.BeanLocation location,
) {
  final d.Amount units = posting.units!;
  Decimal remaining = units.number.abs();
  final Decimal sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
  final List<MutablePosting> out = <MutablePosting>[];
  for (final d.Position match in ordered) {
    if (remaining == Decimal.zero) break;
    final Decimal take = match.units.number.abs() < remaining ? match.units.number.abs() : remaining;
    out.add(
      MutablePosting(
        origin: posting.origin,
        meta: posting.meta,
        flag: posting.flag,
        account: posting.account,
        units: d.Amount(number: take * sign, currency: units.currency),
        cost: match.cost,
        price: posting.price,
      ),
    );
    remaining -= take;
  }
  if (remaining != Decimal.zero) {
    return (
      postings: const <MutablePosting>[],
      errors: <d.ProcessingError>[d.ProcessingError(message: 'Not enough lots to reduce', location: location)],
    );
  }
  return (postings: out, errors: const <d.ProcessingError>[]);
}

d.DirectiveBody _mapCustom(String type, List<p.CustomValue> values, d.AccountPrefixes prefixes) =>
    _budgetFromCustom(type, values, prefixes) ??
    d.DirectiveBody.custom(
      type: type,
      values: <d.CustomValue>[for (final p.CustomValue value in values) _customValue(value, prefixes)],
    );

d.DirectiveBody? _budgetFromCustom(String type, List<p.CustomValue> values, d.AccountPrefixes prefixes) {
  if (type != 'budget' || values.length < 2) {
    return null;
  }
  final String? accountName = _budgetAccountName(values[0]);
  final p.CustomValue interval = values[1];
  if (accountName == null || interval is! p.CustomText) {
    return null;
  }
  final d.Account account = prefixes.budgetAccount(accountName);
  if (_isBudgetOff(interval.value)) {
    if (values.length == 2) {
      return d.DirectiveBody.budgetOff(account: account);
    }
    if (values.length != 3) {
      return null;
    }
    final d.Currency? currency = _budgetOffCurrency(values[2]);
    if (currency == null) {
      return null;
    }
    return d.DirectiveBody.budgetOff(account: account, currency: currency);
  }
  if (values.length != 3) {
    return null;
  }
  final p.CustomValue amount = values[2];
  if (amount is! p.CustomAmount) {
    return null;
  }
  final d.BudgetInterval? parsed = _budgetInterval(interval.value);
  if (parsed == null) {
    return null;
  }
  return d.DirectiveBody.budget(account: account, interval: parsed, amount: mapAmount(amount.value));
}

String? _budgetAccountName(p.CustomValue value) => switch (value) {
  p.CustomAccount(:final p.Account value) => value.name,
  p.CustomText(:final String value) when d.isValidBudgetAccountName(value) => value,
  _ => null,
};

d.Currency? _budgetOffCurrency(p.CustomValue value) => switch (value) {
  p.CustomCurrency(:final p.Currency value) => d.Currency(name: value.name),
  p.CustomAmount(:final p.Amount value) => d.Currency(name: value.currency.name),
  _ => null,
};

bool _isBudgetOff(String value) {
  final String name = value.toLowerCase();
  return name == 'off' || name == 'none';
}

d.BudgetInterval? _budgetInterval(String value) => switch (value.toLowerCase()) {
  'daily' || 'day' => d.BudgetInterval.daily,
  'weekly' || 'week' => d.BudgetInterval.weekly,
  'monthly' || 'month' => d.BudgetInterval.monthly,
  'quarterly' || 'quarter' => d.BudgetInterval.quarterly,
  'yearly' || 'year' => d.BudgetInterval.yearly,
  _ => null,
};

d.CustomValue _customValue(p.CustomValue value, d.AccountPrefixes prefixes) => switch (value) {
  p.CustomText(:final String value) => d.CustomValue.text(value),
  p.CustomAccount(:final p.Account value) => d.CustomValue.account(domainAccount(value.name, prefixes)),
  p.CustomDate(:final p.BeanDate value) => d.CustomValue.date(mapDate(value)),
  p.CustomBoolean(:final bool value) => d.CustomValue.boolean(value),
  p.CustomNumber(:final p.BeanNumber value) => d.CustomValue.number(value.resolved),
  p.CustomAmount(:final p.Amount value) => d.CustomValue.amount(mapAmount(value)),
  p.CustomCurrency(:final p.Currency value) => d.CustomValue.currency(d.Currency(name: value.name)),
};
