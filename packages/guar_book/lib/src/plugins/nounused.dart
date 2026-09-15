// Warn about accounts that are opened but never referenced anywhere else.

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'helpers.dart';

BookPluginResult validateUnusedAccounts(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final opens = <String, Directive>{};
  for (final directive in directives) {
    if (directive.body case OpenBody(:final account)) {
      opens[account.name] = directive;
    }
  }
  final referenced = usedAccounts(directives);

  final errors = <ProcessingError>[];
  for (final entry in opens.entries) {
    if (referenced.contains(entry.key)) continue;
    errors.add(ProcessingError(message: "Unused account '${entry.key}'", location: directiveLocation(entry.value)));
  }
  return (directives: directives, errors: errors);
}
