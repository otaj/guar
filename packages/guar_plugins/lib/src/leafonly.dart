// Reject postings on accounts that have child accounts.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateLeafOnly(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Set<String> referenced = <String>{};
  final Set<String> offending = <String>{};

  void record(String account, {required bool allowed}) {
    referenced.add(account);
    if (!allowed) {
      offending.add(account);
    }
  }

  for (final Directive directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          record(posting.account.name, allowed: false);
        }
      case OpenBody(:final Account account):
        record(account.name, allowed: true);
      case BalanceBody(:final Account account):
        record(account.name, allowed: true);
      case CloseBody(:final Account account):
        record(account.name, allowed: false);
      case NoteBody(:final Account account):
        record(account.name, allowed: false);
      case DocumentBody(:final Account account):
        record(account.name, allowed: false);
      case PadBody(:final Account account, :final Account sourceAccount):
        record(account.name, allowed: false);
        record(sourceAccount.name, allowed: false);
      case CustomBody(:final List<CustomValue> values):
        for (final CustomValue value in values) {
          if (value is CustomAccount) {
            record(value.value.name, allowed: false);
          }
        }
      case BudgetBody(:final Account account) || BudgetOffBody(:final Account account):
        record(account.name, allowed: false);
      default:
        break;
    }
  }

  final Map<String, ({Directive? close, Directive? open})> openClose = accountOpenClose(directives);
  final List<String> names = referenced.toList()..sort();
  final List<ProcessingError> errors = <ProcessingError>[];
  for (final String name in names) {
    if (!offending.contains(name)) continue;
    if (!names.any((String other) => isSubaccountName(other, name))) continue;
    final Directive? open = openClose[name]?.open;
    errors.add(
      ProcessingError(
        message: "Non-leaf account '$name' has postings on it",
        location: open == null ? nowhereLocation('<leafonly>') : directiveLocation(open),
      ),
    );
  }
  return (directives: directives, errors: errors);
}
