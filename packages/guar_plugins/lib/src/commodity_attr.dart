// Require Commodity directives to carry configured metadata attributes.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';
import 'config_literal.dart';
import 'helpers.dart';

BookPluginResult validateCommodityAttr(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final parsed = parseConfigLiteral(config ?? '');
  final configObject = parsed.value;
  if (parsed.error != null || configObject is! Map<Object?, Object?>) {
    return (
      directives: directives,
      errors: [
        ProcessingError(
          message: 'Invalid configuration for commodity_attr plugin; skipping.',
          location: nowhereLocation('<commodity_attr>'),
        ),
      ],
    );
  }

  final validMap = <String, Set<String>?>{};
  for (final entry in configObject.entries) {
    final values = entry.value;
    validMap['${entry.key}'] = values is List<Object?> ? {for (final value in values) '$value'} : null;
  }

  final errors = <ProcessingError>[];
  for (final directive in directives) {
    if (directive.body case CommodityBody(:final currency)) {
      for (final entry in validMap.entries) {
        final value = metaText(directive.meta.lookup(entry.key));
        if (value == null) {
          errors.add(
            ProcessingError(
              message: "Missing attribute '${entry.key}' for Commodity directive ${currency.name}",
              location: directiveLocation(directive),
            ),
          );
          continue;
        }
        final valid = entry.value;
        if (valid != null && valid.isNotEmpty && !valid.contains(value)) {
          errors.add(
            ProcessingError(
              message:
                  "Invalid value '$value' for attribute ${entry.key}, Commodity"
                  ' directive ${currency.name}; valid options: ${valid.join(', ')}',
              location: directiveLocation(directive),
            ),
          );
        }
      }
    }
  }
  return (directives: directives, errors: errors);
}
