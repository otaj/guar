// Lot matching and interpolation of parsed transactions into booked directives.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

import '../map/primitives.dart';
import '../options_defaults.dart';
import '../stage_result.dart';
import 'interpolate.dart';

StageResult bookDirectives({required List<p.ParsedDirective> parsed, required d.LedgerOptions options}) {
  final balances = <String, d.Inventory>{};
  final methods = <String, d.BookingMethod>{};
  final defaultMethod = options.bookingMethod;
  final out = <d.Directive>[];
  final errors = <d.ProcessingError>[];

  for (final directive in parsed) {
    final body = directive.body;
    if (body is p.OpenBody && body.booking != null) {
      methods[body.account.name] = mapBookingMethod(body.booking)!;
    }

    if (body is! p.TransactionBody) {
      final mapped = mapNonTransaction(directive, options.accountPrefixes);
      if (mapped != null) {
        out.add(mapped);
      }
      continue;
    }

    final booked = _bookTransaction(
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
  final origin = sourceOrigin(directive.location);
  final date = mapDate(directive.date);
  final meta = mapMeta(directive.meta);
  final body = switch (directive.body) {
    p.PriceBody(:final currency, :final amount) => d.DirectiveBody.price(
      currency: d.Currency(name: currency.name),
      amount: mapAmount(amount),
    ),
    p.BalanceBody(:final account, :final amount, :final tolerance) => d.DirectiveBody.balance(
      account: domainAccount(account.name, prefixes),
      amount: mapAmount(amount),
      tolerance: tolerance?.resolved,
    ),
    p.OpenBody(:final account, :final currencies, :final booking) => d.DirectiveBody.open(
      account: domainAccount(account.name, prefixes),
      currencies: [for (final currency in currencies) d.Currency(name: currency.name)],
      booking: mapBookingMethod(booking),
    ),
    p.CloseBody(:final account) => d.DirectiveBody.close(account: domainAccount(account.name, prefixes)),
    p.CommodityBody(:final currency) => d.DirectiveBody.commodity(currency: d.Currency(name: currency.name)),
    p.PadBody(:final account, :final sourceAccount) => d.DirectiveBody.pad(
      account: domainAccount(account.name, prefixes),
      sourceAccount: domainAccount(sourceAccount.name, prefixes),
    ),
    p.DocumentBody(:final account, :final filename, :final tags, :final links) => d.DirectiveBody.document(
      account: domainAccount(account.name, prefixes),
      filename: filename,
      tags: [for (final tag in tags) d.Tag(name: tag.name)],
      links: [for (final link in links) d.Link(name: link.name)],
    ),
    p.NoteBody(:final account, :final comment, :final tags, :final links) => d.DirectiveBody.note(
      account: domainAccount(account.name, prefixes),
      comment: comment,
      tags: [for (final tag in tags) d.Tag(name: tag.name)],
      links: [for (final link in links) d.Link(name: link.name)],
    ),
    p.EventBody(:final name, :final description) => d.DirectiveBody.event(name: name, description: description),
    p.QueryBody(:final name, :final queryString) => d.DirectiveBody.query(name: name, queryString: queryString),
    p.CustomBody(:final type, :final values) => d.DirectiveBody.custom(
      type: type,
      values: [for (final value in values) _customValue(value, prefixes)],
    ),
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
  final prefixes = options.accountPrefixes;
  final location = mapLocation(directive.location);
  final date = mapDate(directive.date);
  final origin = sourceOrigin(directive.location);
  final mutable = <MutablePosting>[];

  for (final posting in transaction.postings) {
    final account = domainAccount(posting.account.name, prefixes);
    final units = mapCompleteUnits(posting.units);
    final unitsAbs = units?.number.abs();
    final resolvedCost = units == null ? null : mapResolvedCost(posting.cost, date, unitsAbs!);
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
    final price = mapPrice(posting.price, unitsAbs);
    mutable.add(
      MutablePosting(
        origin: sourceOrigin(posting.location),
        meta: mapMeta(posting.meta),
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
  final booked = <MutablePosting>[];
  final errors = <d.ProcessingError>[];
  for (final posting in mutable) {
    final units = posting.units;
    final method = methods[posting.account.name] ?? defaultMethod;
    final balance = balances[posting.account.name] ?? d.Inventory();
    final isReduction =
        units != null &&
        (posting.cost != null || posting.pendingCost != null) &&
        method != d.BookingMethod.none &&
        _isReducedBy(balance, units);

    if (!isReduction) {
      booked.add(posting);
      continue;
    }

    final matches = _matchLots(balance, units, posting.cost ?? posting.pendingCost?.toCost(units.number.abs()));
    if (matches.isEmpty) {
      errors.add(
        d.ProcessingError(
          message: 'No position matches "${posting.account.name}" against balance $balance',
          location: location,
        ),
      );
      return (directive: null, errors: errors);
    }

    final reduced = _applyMethod(method, posting, matches, location);
    if (reduced.errors.isNotEmpty) {
      return (directive: null, errors: reduced.errors);
    }
    booked.addAll(reduced.postings);
  }

  final tolerancesMax = inferTolerances(booked, options);
  final tolerancesInterp = options.usePreciseInterpolation
      ? inferTolerances(booked, options, mode: ToleranceMode.min)
      : tolerancesMax;

  final interpolated = interpolateGroup(booked, location, tolerancesInterp);
  if (interpolated.errors.isNotEmpty) {
    return (directive: null, errors: interpolated.errors);
  }
  final rounding = options.accountRounding;
  if (rounding != null) {
    fillResidualPostings(interpolated.postings, rounding);
  }

  for (final posting in interpolated.postings) {
    if (posting.units != null &&
        posting.units!.number == Decimal.zero &&
        (posting.cost != null || posting.pendingCost != null)) {
      return (directive: null, errors: [d.ProcessingError(message: 'Amount is zero', location: location)]);
    }
  }

  final postings = <d.Posting>[];
  for (final posting in interpolated.postings) {
    try {
      postings.add(posting.toPosting());
    } catch (_) {
      return (
        directive: null,
        errors: [d.ProcessingError(message: 'Transaction has incomplete elements', location: location)],
      );
    }
  }

  for (final posting in postings) {
    final current = balances[posting.account.name] ?? d.Inventory();
    balances[posting.account.name] = current
        .addPosition(d.Position(units: posting.units, cost: posting.cost))
        .inventory;
  }

  return (
    directive: d.Directive(
      origin: origin,
      date: date,
      meta: mapMeta(directive.meta),
      body: d.DirectiveBody.transaction(
        d.Transaction(
          origin: origin,
          flag: mapFlag(transaction.flag),
          payee: transaction.payee,
          narration: transaction.narration,
          tags: [for (final tag in transaction.tags) d.Tag(name: tag.name)],
          links: [for (final link in transaction.links) d.Link(name: link.name)],
          postings: postings,
        ),
      ),
    ),
    errors: const [],
  );
}

bool _isReducedBy(d.Inventory balance, d.Amount units) {
  for (final position in balance.positions) {
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
  final matches = <d.Position>[];
  for (final position in balance.positions) {
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
      final ordered = [...matches]
        ..sort((a, b) {
          if (method == d.BookingMethod.hifo) {
            return -a.cost!.number.compareTo(b.cost!.number);
          }
          final byDate = _compareDate(a.cost!.date, b.cost!.date);
          return method == d.BookingMethod.lifo ? -byDate : byDate;
        });
      return _applyXifo(posting, ordered, location);
    case d.BookingMethod.none:
      return (postings: [posting], errors: const []);
    case d.BookingMethod.average:
      return _applyAverage(posting, matches, location);
  }
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyAverage(
  MutablePosting posting,
  List<d.Position> matches,
  d.BeanLocation location,
) {
  final units = posting.units!;
  final hasExplicitCost =
      posting.cost != null ||
      (posting.pendingCost != null &&
          (posting.pendingCost!.numberPer != null || posting.pendingCost!.numberTotal != null));

  if (matches.length == 1 && !hasExplicitCost) {
    final match = matches.single;
    final sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
    final take = match.units.number.abs() < units.number.abs() ? match.units.number.abs() : units.number.abs();
    if (take != units.number.abs()) {
      return (
        postings: const [],
        errors: [d.ProcessingError(message: 'Not enough lots to reduce', location: location)],
      );
    }
    return (
      postings: [
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
      errors: const [],
    );
  }

  var totalUnits = Decimal.zero;
  var totalCost = Decimal.zero;
  final unitCurrencies = <String>{};
  final costCurrencies = <String>{};
  for (final match in matches) {
    unitCurrencies.add(match.units.currency.name);
    costCurrencies.add(match.cost!.currency.name);
    totalUnits += match.units.number;
    totalCost += match.units.number * match.cost!.number;
  }
  if (unitCurrencies.length != 1 || costCurrencies.length != 1) {
    final detail = matches.map(_positionString).join(', ');
    return (
      postings: const [],
      errors: [
        d.ProcessingError(message: 'Cannot merge positions in multiple currencies: $detail', location: location),
      ],
    );
  }
  if (hasExplicitCost) {
    return (
      postings: const [],
      errors: [
        d.ProcessingError(
          message: 'Explicit cost reductions aren\'t supported yet: ${_postingString(posting)}',
          location: location,
        ),
      ],
    );
  }
  if (units.number.abs() > totalUnits.abs()) {
    return (postings: const [], errors: [d.ProcessingError(message: 'Not enough lots to reduce', location: location)]);
  }

  final mergeFlag = d.Flag.letter('M');
  final avgCost = d.Cost(
    number: (totalCost / totalUnits).toDecimal(scaleOnInfinitePrecision: 28),
    currency: matches.first.cost!.currency,
    date: matches.first.cost!.date,
    label: null,
  );
  final out = <MutablePosting>[
    for (final match in matches)
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
  return (postings: out, errors: const []);
}

String _positionString(d.Position position) {
  final cost = position.cost;
  if (cost == null) {
    return '${position.units.number} ${position.units.currency.name}';
  }
  final date = '${cost.date}';
  final label = cost.label == null ? '' : ' "${cost.label}"';
  return '${position.units.number} ${position.units.currency.name} {${cost.number} ${cost.currency.name}, $date$label}';
}

String _postingString(MutablePosting posting) {
  final units = posting.units;
  if (units == null) {
    return posting.account.name;
  }
  final cost = posting.cost ?? posting.pendingCost?.toCost(units.number.abs());
  if (cost == null) {
    final pending = posting.pendingCost;
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
  final units = posting.units!;
  if (matches.length > 1) {
    final sumMatches = matches.fold<Decimal>(Decimal.zero, (sum, match) => sum + match.units.number);
    if (sumMatches == -units.number) {
      return (
        postings: [
          for (final match in matches)
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
        errors: const [],
      );
    }
    if (withSize) {
      final want = -units.number;
      final sized = matches.where((match) => match.units.number == want).toList()
        ..sort((a, b) => _compareDate(a.cost!.date, b.cost!.date));
      if (sized.isNotEmpty) {
        final match = sized.first;
        return (
          postings: [
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
          errors: const [],
        );
      }
    }
    return (
      postings: const [],
      errors: [
        d.ProcessingError(
          message: 'Ambiguous matches for inventory reduction: ${matches.length} matching lots',
          location: location,
        ),
      ],
    );
  }
  final match = matches.single;
  final sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
  final take = match.units.number.abs() < units.number.abs() ? match.units.number.abs() : units.number.abs();
  if (take != units.number.abs()) {
    return (postings: const [], errors: [d.ProcessingError(message: 'Not enough lots to reduce', location: location)]);
  }
  return (
    postings: [
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
    errors: const [],
  );
}

({List<MutablePosting> postings, List<d.ProcessingError> errors}) _applyXifo(
  MutablePosting posting,
  List<d.Position> ordered,
  d.BeanLocation location,
) {
  final units = posting.units!;
  var remaining = units.number.abs();
  final sign = units.number < Decimal.zero ? Decimal.fromInt(-1) : Decimal.one;
  final out = <MutablePosting>[];
  for (final match in ordered) {
    if (remaining == Decimal.zero) break;
    final take = match.units.number.abs() < remaining ? match.units.number.abs() : remaining;
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
    return (postings: const [], errors: [d.ProcessingError(message: 'Not enough lots to reduce', location: location)]);
  }
  return (postings: out, errors: const []);
}

int _compareDate(d.BeanDate a, d.BeanDate b) {
  final byYear = a.year.compareTo(b.year);
  if (byYear != 0) return byYear;
  final byMonth = a.month.compareTo(b.month);
  if (byMonth != 0) return byMonth;
  return a.day.compareTo(b.day);
}

d.CustomValue _customValue(p.CustomValue value, d.AccountPrefixes prefixes) => switch (value) {
  p.CustomText(:final value) => d.CustomValue.text(value),
  p.CustomAccount(:final value) => d.CustomValue.account(domainAccount(value.name, prefixes)),
  p.CustomDate(:final value) => d.CustomValue.date(mapDate(value)),
  p.CustomBoolean(:final value) => d.CustomValue.boolean(value),
  p.CustomNumber(:final value) => d.CustomValue.number(value.resolved),
  p.CustomAmount(:final value) => d.CustomValue.amount(mapAmount(value)),
};
