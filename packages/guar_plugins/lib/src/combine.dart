// Compose multiple BookPlugins into one sequential pipeline.

import 'package:guar_domain/guar_domain.dart';

import 'package:guar_plugins/src/plugin.dart';

BookPlugin combinePlugins(List<BookPlugin> plugins) =>
    (List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config) {
      List<Directive> current = directives;
      final List<ProcessingError> errors = <ProcessingError>[];
      for (final BookPlugin plugin in plugins) {
        final BookPluginResult result = plugin(current, options, info, config);
        current = result.directives;
        errors.addAll(result.errors);
      }
      return (directives: current, errors: errors);
    };
