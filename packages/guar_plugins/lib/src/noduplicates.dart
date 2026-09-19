// Reject ledgers containing two identical directives (metadata excluded).

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateNoDuplicates(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final Map<String, Directive> seen = <String, Directive>{};
  final List<ProcessingError> errors = <ProcessingError>[];
  for (final Directive directive in directives) {
    final String hash = directive.hash;
    final Directive? other = seen[hash];
    // Exact duplicate price directives are legal: repeated fetches are common.
    if (other != null && directive.body is! PriceBody) {
      errors.add(ProcessingError(message: 'Duplicate entry: $hash', location: directiveLocation(directive)));
    }
    seen[hash] = directive;
  }
  return (directives: directives, errors: errors);
}
