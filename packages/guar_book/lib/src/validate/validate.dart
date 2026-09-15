// Port of beancount ops.validation BASIC_VALIDATIONS.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

import '../booking/interpolate.dart';

List<ProcessingError> validateDirectives(List<Directive> directives, LedgerOptions options) {
  return [
    ...validateOpenClose(directives),
    ...validateActiveAccounts(directives),
    ...validateCurrencyConstraints(directives),
    ...validateDuplicateBalances(directives),
    ...validateDuplicateCommodities(directives),
    ...validateDocumentPaths(directives),
    ...validateTransactionBalances(directives, options),
  ];
}

List<ProcessingError> validateOpenClose(List<Directive> directives) {
  final errors = <ProcessingError>[];
  final opens = <String, Directive>{};
  final closes = <String, Directive>{};
  for (final directive in directives) {
    final body = directive.body;
    final location = _location(directive);
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
        final open = opens[body.account.name];
        if (open == null) {
          errors.add(
            ProcessingError(message: 'Unopened account ${body.account.name} is being closed', location: location),
          );
        } else if (_compareDate(directive.date, open.date) < 0) {
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
  final errors = <ProcessingError>[];
  final open = <String>{};
  final closed = <String>{};
  for (final directive in directives) {
    final body = directive.body;
    final location = _location(directive);
    switch (body) {
      case OpenBody(:final account):
        open.add(account.name);
        closed.remove(account.name);
      case CloseBody(:final account):
        closed.add(account.name);
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          _checkActive(posting.account.name, open, closed, location, errors);
        }
      case BalanceBody(:final account):
        // Balance allowed after close.
        if (!open.contains(account.name) && !closed.contains(account.name)) {
          errors.add(
            ProcessingError(message: "Invalid reference to unknown account '${account.name}'", location: location),
          );
        }
      case PadBody(:final account, :final sourceAccount):
        _checkActive(account.name, open, closed, location, errors);
        _checkActive(sourceAccount.name, open, closed, location, errors);
      case NoteBody(:final account):
      case DocumentBody(:final account):
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
  final errors = <ProcessingError>[];
  final allowed = <String, Set<String>>{};
  for (final directive in directives) {
    final body = directive.body;
    if (body is OpenBody && body.currencies.isNotEmpty) {
      allowed[body.account.name] = {for (final currency in body.currencies) currency.name};
    } else if (body is TransactionBody) {
      for (final posting in body.value.postings) {
        final set = allowed[posting.account.name];
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
  final errors = <ProcessingError>[];
  final seen = <String>{};
  for (final directive in directives) {
    final body = directive.body;
    if (body is! BalanceBody) continue;
    final key = '${directive.date}:${body.account.name}:${body.amount.currency.name}';
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
  final errors = <ProcessingError>[];
  final seen = <String>{};
  for (final directive in directives) {
    final body = directive.body;
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
  final errors = <ProcessingError>[];
  for (final directive in directives) {
    final body = directive.body;
    if (body is! DocumentBody) continue;
    if (body.filename.contains(String.fromCharCode(0))) {
      errors.add(ProcessingError(message: 'Invalid document path', location: _location(directive)));
    }
  }
  return errors;
}

List<ProcessingError> validateTransactionBalances(List<Directive> directives, LedgerOptions options) {
  final errors = <ProcessingError>[];
  final multiplier = options.toleranceMultiplier ?? Decimal.parse('0.5');
  for (final directive in directives) {
    final body = directive.body;
    if (body is! TransactionBody) continue;
    final residual = <String, Decimal>{};
    for (final posting in body.value.postings) {
      final mutable = MutablePosting(
        origin: posting.origin,
        meta: posting.meta,
        flag: posting.flag,
        account: posting.account,
        units: posting.units,
        cost: posting.cost,
        price: posting.price,
      );
      final weight = postingWeight(mutable);
      residual.update(weight.currency.name, (value) => value + weight.number, ifAbsent: () => weight.number);
    }
    for (final entry in residual.entries) {
      final tolerance = _toleranceFor(entry.key, body.value.postings, multiplier);
      if (entry.value.abs() > tolerance) {
        errors.add(
          ProcessingError(
            message: 'Transaction does not balance: ${entry.value} ${entry.key}',
            location: _location(directive),
          ),
        );
      }
    }
  }
  return errors;
}

Decimal _toleranceFor(String currency, List<Posting> postings, Decimal multiplier) {
  var maxScale = 0;
  for (final posting in postings) {
    if (posting.units.currency.name == currency) {
      maxScale = maxScale > posting.units.number.scale ? maxScale : posting.units.number.scale;
    }
  }
  if (maxScale <= 0) {
    return Decimal.zero;
  }
  return Decimal.parse('1e-$maxScale') * multiplier;
}

BeanLocation _location(Directive directive) => switch (directive.origin) {
  SourceOrigin(:final location) => location,
  GeneratedOrigin() => BeanLocation(linenoBegin: 0, linenoEnd: 0),
};

int _compareDate(BeanDate a, BeanDate b) {
  final byYear = a.year.compareTo(b.year);
  if (byYear != 0) return byYear;
  final byMonth = a.month.compareTo(b.month);
  if (byMonth != 0) return byMonth;
  return a.day.compareTo(b.day);
}
