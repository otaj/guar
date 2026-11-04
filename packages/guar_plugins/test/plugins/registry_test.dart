// Completeness of defaultPlugins versus stock and reds maps.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/guar_plugins.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('defaultPlugins is the union of stock and reds', () {
    expect(defaultPlugins.keys.toSet(), <String>{...stockPlugins.keys, ...redsPlugins.keys});
  });

  test('the catalog is the registry, and every plugin has a description', () {
    expect(pluginCatalog.map((PluginDeclaration plugin) => plugin.name), defaultPlugins.keys);
    for (final PluginDeclaration plugin in pluginCatalog) {
      expect(plugin.description.trim(), isNotEmpty, reason: plugin.name);
      expect(defaultPlugins[plugin.name], same(plugin.apply), reason: plugin.name);
      final PluginSetup? setup = plugin.setup;
      if (setup == null) continue;
      expect(setup.encode(setup.decode(null)).error, isNull, reason: plugin.name);
    }
  });

  test('every registered plugin name resolves in Book', () {
    for (final String name in defaultPlugins.keys) {
      final Ledger ledger = process(
        'plugin "$name"\n'
        '2014-01-01 open Assets:Cash USD\n',
      );
      final List<ProcessingError> errors = switch (ledger) {
        LedgerDirectives(:final List<ProcessingError> errors) => errors,
        LedgerErrors(:final List<ProcessingError> errors) => errors,
      };
      expect(
        errors.where((ProcessingError error) => error.message.contains('plugin not registered')),
        isEmpty,
        reason: name,
      );
    }
  });
}
