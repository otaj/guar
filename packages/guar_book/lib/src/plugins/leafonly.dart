// Reject postings on accounts that have child accounts.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'helpers.dart';

BookPluginResult validateLeafOnly(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final referenced = <String>{};
  final offending = <String>{};

  void record(String account, {required bool allowed}) {
    referenced.add(account);
    if (!allowed) {
      offending.add(account);
    }
  }

  for (final directive in directives) {
    switch (directive.body) {
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          record(posting.account.name, allowed: false);
        }
      case OpenBody(:final account):
        record(account.name, allowed: true);
      case BalanceBody(:final account):
        record(account.name, allowed: true);
      case CloseBody(:final account):
        record(account.name, allowed: false);
      case NoteBody(:final account):
        record(account.name, allowed: false);
      case DocumentBody(:final account):
        record(account.name, allowed: false);
      case PadBody(:final account, :final sourceAccount):
        record(account.name, allowed: false);
        record(sourceAccount.name, allowed: false);
      case CustomBody(:final values):
        for (final value in values) {
          if (value is CustomAccount) {
            record(value.value.name, allowed: false);
          }
        }
      default:
        break;
    }
  }

  final openClose = accountOpenClose(directives);
  final names = referenced.toList()..sort();
  final errors = <ProcessingError>[];
  for (final name in names) {
    if (!offending.contains(name)) continue;
    if (!names.any((other) => isStrictParentOf(name, other))) continue;
    final open = openClose[name]?.open;
    errors.add(
      ProcessingError(
        message: "Non-leaf account '$name' has postings on it",
        location: open == null ? nowhereLocation('<leafonly>') : directiveLocation(open),
      ),
    );
  }
  return (directives: directives, errors: errors);
}
