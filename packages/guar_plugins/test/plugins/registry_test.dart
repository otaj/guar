// Completeness of defaultPlugins versus stock and reds maps.

import 'package:guar_domain/guar_domain.dart';
import 'package:guar_plugins/guar_plugins.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('defaultPlugins is the union of stock and reds', () {
    expect(defaultPlugins.keys.toSet(), {...stockPlugins.keys, ...redsPlugins.keys});
  });

  test('every registered plugin name resolves in Book', () {
    for (final name in defaultPlugins.keys) {
      final ledger = process(
        'plugin "$name"\n'
        '2014-01-01 open Assets:Cash USD\n',
      );
      final errors = switch (ledger) {
        LedgerDirectives(:final errors) => errors,
        LedgerErrors(:final errors) => errors,
      };
      expect(errors.where((error) => error.message.contains('plugin not registered')), isEmpty, reason: name);
    }
  });
}
