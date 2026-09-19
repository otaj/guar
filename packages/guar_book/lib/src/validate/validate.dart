// Port of beancount ops.validation BASIC_VALIDATIONS.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/booking/interpolate.dart';
import 'package:guar_domain/guar_domain.dart';

List<ProcessingError> validateDirectives(List<Directive> directives, LedgerOptions options) => <ProcessingError>[
  ...validateOpenClose(directives),
  ...validateActiveAccounts(directives),
  ...validateCurrencyConstraints(directives),
  ...validateDuplicateBalances(directives),
  ...validateDuplicateCommodities(directives),
  ...validateDocumentPaths(directives),
  ...validateTransactionBalances(directives, options),
];

List<ProcessingError> validateOpenClose(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Map<String, Directive> opens = <String, Directive>{};
  final Map<String, Directive> closes = <String, Directive>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    final BeanLocation location = _location(directive);
    if (body is OpenBody) {
      if (opens.containsKey(body.account.name)) {
        errors.add(ProcessingError(message: 'Duplicate open directive for ${body.account.name}', location: location));
      } else {
        opens[body.account.name] = directive;
      }
    } else if (body is CloseBody) {
      if (closes.containsKey(body.account.name)) {
        errors.add(ProcessingError(message: 'Duplicate close directive for ${body.account.name}', location: location));
      } else {
        final Directive? open = opens[body.account.name];
        if (open == null) {
          errors.add(
            ProcessingError(message: 'Unopened account ${body.account.name} is being closed', location: location),
          );
        } else if (compareBeanDate(directive.date, open.date) < 0) {
          errors.add(
            ProcessingError(
              message: 'Internal error: closing date for ${body.account.name} appears before opening date',
              location: location,
            ),
          );
        }
        closes[body.account.name] = directive;
      }
    }
  }
  return errors;
}

List<ProcessingError> validateActiveAccounts(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Set<String> open = <String>{};
  final Set<String> closed = <String>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    final BeanLocation location = _location(directive);
    switch (body) {
      case OpenBody(:final Account account):
        open.add(account.name);
        closed.remove(account.name);
      case CloseBody(:final Account account):
        closed.add(account.name);
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          _checkActive(posting.account.name, open, closed, location, errors);
        }
      case BalanceBody(:final Account account):
        // Balance allowed after close.
        if (!open.contains(account.name) && !closed.contains(account.name)) {
          errors.add(
            ProcessingError(message: "Invalid reference to unknown account '${account.name}'", location: location),
          );
        }
      case PadBody(:final Account account, :final Account sourceAccount):
        _checkActive(account.name, open, closed, location, errors);
        _checkActive(sourceAccount.name, open, closed, location, errors);
      case NoteBody(:final Account account):
      case DocumentBody(:final Account account):
        if (!open.contains(account.name) && !closed.contains(account.name)) {
          errors.add(
            ProcessingError(message: "Invalid reference to unknown account '${account.name}'", location: location),
          );
        }
      default:
        break;
    }
  }
  return errors;
}

void _checkActive(
  String account,
  Set<String> open,
  Set<String> closed,
  BeanLocation location,
  List<ProcessingError> errors,
) {
  if (!open.contains(account)) {
    errors.add(ProcessingError(message: "Invalid reference to unknown account '$account'", location: location));
  } else if (closed.contains(account)) {
    errors.add(ProcessingError(message: "Invalid reference to closed account '$account'", location: location));
  }
}

List<ProcessingError> validateCurrencyConstraints(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Map<String, Set<String>> allowed = <String, Set<String>>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is OpenBody && body.currencies.isNotEmpty) {
      allowed[body.account.name] = <String>{for (final Currency currency in body.currencies) currency.name};
    } else if (body is TransactionBody) {
      for (final Posting posting in body.value.postings) {
        final Set<String>? set = allowed[posting.account.name];
        if (set == null) continue;
        if (!set.contains(posting.units.currency.name)) {
          errors.add(
            ProcessingError(
              message: 'Invalid currency ${posting.units.currency.name} for account ${posting.account.name}',
              location: _location(directive),
            ),
          );
        }
      }
    }
  }
  return errors;
}

List<ProcessingError> validateDuplicateBalances(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Set<String> seen = <String>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! BalanceBody) continue;
    final String key = '${directive.date}:${body.account.name}:${body.amount.currency.name}';
    if (!seen.add(key)) {
      errors.add(
        ProcessingError(
          message: 'Duplicate balance assertion for ${body.account.name} in ${body.amount.currency.name}',
          location: _location(directive),
        ),
      );
    }
  }
  return errors;
}

List<ProcessingError> validateDuplicateCommodities(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  final Set<String> seen = <String>{};
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! CommodityBody) continue;
    if (!seen.add(body.currency.name)) {
      errors.add(
        ProcessingError(
          message: 'Duplicate commodity directive for ${body.currency.name}',
          location: _location(directive),
        ),
      );
    }
  }
  return errors;
}

List<ProcessingError> validateDocumentPaths(List<Directive> directives) {
  final List<ProcessingError> errors = <ProcessingError>[];
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! DocumentBody) continue;
    if (body.filename.contains(String.fromCharCode(0))) {
      errors.add(ProcessingError(message: 'Invalid document path', location: _location(directive)));
    }
  }
  return errors;
}

List<ProcessingError> validateTransactionBalances(List<Directive> directives, LedgerOptions options) {
  final List<ProcessingError> errors = <ProcessingError>[];
  for (final Directive directive in directives) {
    final DirectiveBody body = directive.body;
    if (body is! TransactionBody) continue;
    final Map<String, Decimal> residual = <String, Decimal>{};
    for (final Posting posting in body.value.postings) {
      final MutablePosting mutable = MutablePosting(
        origin: posting.origin,
        meta: posting.meta,
        flag: posting.flag,
        account: posting.account,
        units: posting.units,
        cost: posting.cost,
        price: posting.price,
      );
      final Amount weight = postingWeight(mutable);
      residual.update(weight.currency.name, (Decimal value) => value + weight.number, ifAbsent: () => weight.number);
    }
    final InferredTolerances tolerances = inferPostingTolerances(body.value.postings, options);
    final List<MapEntry<String, Decimal>> large = <MapEntry<String, Decimal>>[
      for (final MapEntry<String, Decimal> entry in residual.entries)
        if (entry.value.abs() > tolerances[entry.key]) entry,
    ];
    if (large.length == 1) {
      errors.add(
        ProcessingError(
          message: 'Transaction does not balance: ${large.single.value} ${large.single.key}',
          location: _location(directive),
        ),
      );
    }
  }
  return errors;
}

BeanLocation _location(Directive directive) => switch (directive.origin) {
  SourceOrigin(:final BeanLocation location) => location,
  GeneratedOrigin() => BeanLocation(linenoBegin: 0, linenoEnd: 0),
};
