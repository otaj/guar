// Warn about accounts that are opened but never referenced anywhere else.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateUnusedAccounts(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Map<String, Directive> opens = <String, Directive>{};
  for (final Directive directive in directives) {
    if (directive.body case OpenBody(:final Account account)) {
      opens[account.name] = directive;
    }
  }
  final Set<String> referenced = usedAccounts(directives);

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final MapEntry<String, Directive> entry in opens.entries) {
    if (referenced.contains(entry.key)) continue;
    errors.add(ProcessingError(message: "Unused account '${entry.key}'", location: directiveLocation(entry.value)));
  }
  return (directives: directives, errors: errors);
}
