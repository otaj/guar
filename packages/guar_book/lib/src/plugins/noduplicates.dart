// Reject ledgers containing two identical directives (metadata excluded).

import 'package:guar_domain/guar_domain.dart';

import '../plugin.dart';
import 'helpers.dart';

BookPluginResult validateNoDuplicates(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final seen = <String, Directive>{};
  final errors = <ProcessingError>[];
  for (final directive in directives) {
    final hash = contentHash(directive);
    final other = seen[hash];
    // Exact duplicate price directives are legal: repeated fetches are common.
    if (other != null && directive.body is! PriceBody) {
      errors.add(ProcessingError(message: 'Duplicate entry: $hash', location: directiveLocation(directive)));
    }
    seen[hash] = directive;
  }
  return (directives: directives, errors: errors);
}
