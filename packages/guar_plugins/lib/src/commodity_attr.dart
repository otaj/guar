// Require Commodity directives to carry configured metadata attributes.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:guar_plugins/src/helpers.dart';
import 'package:guar_plugins/src/plugin.dart';

BookPluginResult validateCommodityAttr(
  List<Directive> directives,
  LedgerOptions options,
  ProcessingInfo info,
  String? config,
) {
  final ConfigLiteral parsed = parseConfigLiteral(config ?? '');
  final Object? configObject = parsed.value;
  if (parsed.error != null || configObject is! Map<Object?, Object?>) {
    return (
      directives: directives,
      errors: <ProcessingError>[
        ProcessingError(
          message: 'Invalid configuration for commodity_attr plugin; skipping.',
          location: nowhereLocation('<commodity_attr>'),
        ),
      ],
    );
  }

  final Map<String, Set<String>?> validMap = <String, Set<String>?>{};
  for (final MapEntry<Object?, Object?> entry in configObject.entries) {
    final Object? values = entry.value;
    validMap['${entry.key}'] = values is List<Object?> ? <String>{for (final Object? value in values) '$value'} : null;
  }

  final List<ProcessingError> errors = <ProcessingError>[];
  for (final Directive directive in directives) {
    if (directive.body case CommodityBody(:final Currency currency)) {
      for (final MapEntry<String, Set<String>?> entry in validMap.entries) {
        final String? value = metaText(directive.meta.lookup(entry.key));
        if (value == null) {
          errors.add(
            ProcessingError(
              message: "Missing attribute '${entry.key}' for Commodity directive ${currency.name}",
              location: directiveLocation(directive),
            ),
          );
          continue;
        }
        final Set<String>? valid = entry.value;
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
