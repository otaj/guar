// Compose multiple BookPlugins into one sequential pipeline.

import 'package:guar_domain/guar_domain.dart';

import 'plugin.dart';

BookPlugin combinePlugins(List<BookPlugin> plugins) {
  return (directives, options, info, config) {
    var current = directives;
    final errors = <ProcessingError>[];
    for (final plugin in plugins) {
      final result = plugin(current, options, info, config);
      current = result.directives;
      errors.addAll(result.errors);
    }
    return (directives: current, errors: errors);
  };
}
