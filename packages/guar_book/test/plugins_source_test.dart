// Plugin directives round-trip through the root file without moving other lines.

import 'package:guar_book/guar_book.dart';
import 'package:test/test.dart';

void main() {
  test('reads plugins in file order', () {
    final List<LedgerPlugin> plugins = readLedgerPlugins(
      'plugin "beancount.plugins.auto"\n'
      'plugin "beancount.plugins.leafonly" "x"\n',
    );
    expect(plugins.map((LedgerPlugin plugin) => plugin.name), <String>[
      'beancount.plugins.auto',
      'beancount.plugins.leafonly',
    ]);
    expect(plugins[1].config, 'x');
  });

  test('inserts the first plugin after the option lines', () {
    const String source = 'option "title" "Mine"\n2020-01-01 open Assets:Cash\n';
    expect(
      writeLedgerPlugins(source, const <LedgerPlugin>[LedgerPlugin(name: 'beancount.plugins.auto')]),
      'option "title" "Mine"\n'
      'plugin "beancount.plugins.auto"\n'
      '2020-01-01 open Assets:Cash\n',
    );
  });

  test('reorders plugins where the first one stood', () {
    const String source =
        '2020-01-01 open Assets:Cash\n'
        'plugin "a"\n'
        'plugin "b"\n';
    expect(
      writeLedgerPlugins(source, const <LedgerPlugin>[
        LedgerPlugin(name: 'b'),
        LedgerPlugin(name: 'a', config: 'cfg'),
      ]),
      '2020-01-01 open Assets:Cash\n'
      'plugin "b"\n'
      'plugin "a" "cfg"\n',
    );
  });

  test('removes every plugin line', () {
    expect(
      writeLedgerPlugins('plugin "a"\n2020-01-01 open Assets:Cash\n', const <LedgerPlugin>[]),
      '2020-01-01 open Assets:Cash\n',
    );
  });

  test('keeps a configuration that spans lines', () {
    const String source =
        'plugin "beancount.plugins.commodity_attr" "{\n'
        "  'strategy': ['bigtech'],\n"
        '}"\n';
    expect(writeLedgerPlugins(source, readLedgerPlugins(source)), source);
  });

  test('rejects a double quote in a configuration', () {
    expect(
      () => writeLedgerPlugins('', const <LedgerPlugin>[LedgerPlugin(name: 'a', config: 'say "hi"')]),
      throwsFormatException,
    );
  });
}
