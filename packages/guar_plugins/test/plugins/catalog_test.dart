// Configuration codecs round-trip the literals each plugin already accepts.

import 'package:decimal/decimal.dart';
import 'package:guar_plugins/guar_plugins.dart';
import 'package:guar_plugins/src/config_literal.dart';
import 'package:test/test.dart';

void main() {
  PluginSetup setup(String name) => pluginCatalog.firstWhere((PluginDeclaration plugin) => plugin.name == name).setup!;

  test('average cost omits an empty tolerance and writes a float', () {
    final PluginSetup codec = setup('beancount.plugins.check_average_cost');
    expect(codec.encode(codec.decode(null)).config, isNull);
    expect(codec.encode(codec.decode('0.02')).config, '0.02');
    expect(codec.decode('0.02').decimals['tolerance'], Decimal.parse('0.02'));
    expect(codec.encode(codec.decode('1')).config, '1.0');
  });

  test('commodity attributes encode lists and None', () {
    final PluginSetup codec = setup('beancount.plugins.commodity_attr');
    final PluginStored stored = codec.decode("{'strategy': ['bigtech', 'bonds'], 'name': None}");
    final List<List<PluginCell>> rows = stored.tables['attributes']!;
    expect((rows[0][0] as PluginTextCell).value, 'strategy');
    expect((rows[0][1] as PluginTextCell).value, 'bigtech, bonds');
    expect((rows[1][0] as PluginTextCell).value, 'name');
    expect((rows[1][1] as PluginTextCell).value, '');
    expect(codec.encode(stored).config, "{'strategy': ['bigtech', 'bonds'], 'name': None}");
    expect(codec.encode(codec.decode(null)).config, '{}');
  });

  test('currency accounts keep a raw account and reject a bad one', () {
    final PluginSetup codec = setup('beancount.plugins.currency_accounts');
    expect(codec.encode(codec.decode(null)).config, isNull);
    expect(
      codec.encode(const PluginStored(text: <String, String>{'base': 'Equity:Trading'})).config,
      'Equity:Trading',
    );
    expect(codec.encode(const PluginStored(text: <String, String>{'base': 'cash'})).error, isNotNull);
  });

  test('onecommodity rejects a broken regular expression', () {
    final PluginSetup codec = setup('beancount.plugins.onecommodity');
    expect(codec.encode(const PluginStored(text: <String, String>{'accounts': 'Assets:.*'})).config, 'Assets:.*');
    expect(codec.encode(const PluginStored(text: <String, String>{'accounts': '['})).error, isNotNull);
  });

  test('daf mirror keeps a prefix string and writes a dict for a custom payee', () {
    final PluginSetup codec = setup('beancount_reds_plugins.daf.daf_mirror');
    expect(codec.decode('Assets:Giving').text['prefix'], 'Assets:Giving');
    expect(codec.encode(codec.decode('Assets:Giving')).config, 'Assets:Giving');
    expect(codec.encode(codec.decode(null)).config, isNull);
    expect(
      codec
          .encode(
            const PluginStored(
              text: <String, String>{'prefix': 'Assets:Giving', 'payee': 'Copy '},
            ),
          )
          .config,
      "{'account_prefix': 'Assets:Giving', 'payee_prefix': 'Copy '}",
    );
  });

  test('rename, gain and loss, and long and short round-trip their rules', () {
    final PluginSetup rename = setup('beancount_reds_plugins.rename_accounts.rename_accounts');
    expect(
      rename.encode(rename.decode("{'Expenses:Taxes': 'Income:Taxes'}")).config,
      "{'Expenses:Taxes': 'Income:Taxes'}",
    );

    const String gains =
        "{'Income.*:Capital-Gains.*': [':Capital-Gains', ':Capital-Gains:Gains', ':Capital-Gains:Losses']}";
    final PluginSetup gainLoss = setup('beancount_reds_plugins.capital_gains_classifier.gain_loss');
    expect(gainLoss.encode(gainLoss.decode(gains)).config, gains);

    const String holding =
        "{'Income.*:Capital-Gains': [':Capital-Gains', ':Capital-Gains:Short', ':Capital-Gains:Long']}";
    final PluginSetup longShort = setup('beancount_reds_plugins.capital_gains_classifier.long_short');
    expect(longShort.encode(longShort.decode(holding)).config, holding);
  });

  test('effective date and opengroup round-trip nested rules', () {
    const String holding = "{'Expenses': {'earlier': 'Liabilities:Hold:Expenses', 'later': 'Assets:Hold:Expenses'}}";
    final PluginSetup dates = setup('beancount_reds_plugins.effective_date.effective_date');
    expect(dates.encode(dates.decode(holding)).config, holding);

    const String rules = "{'cash': ['(?P<root>.*)', [['Assets:{root}', 'USD']]]}";
    final PluginSetup groups = setup('beancount_reds_plugins.opengroup.opengroup');
    expect(groups.encode(groups.decode(rules)).config, rules);
  });

  test('zerosum keeps the accounts, replacement, and tolerance', () {
    const String config =
        "{'zerosum_accounts': {'Assets:Zero': ['', 90]}, 'account_name_replace': ['Zero', 'Matched'], 'tolerance': 0.0098}";
    final PluginSetup codec = setup('beancount_reds_plugins.zerosum.zerosum');
    final PluginStored stored = codec.decode(config);
    expect(stored.decimals['tolerance'], Decimal.parse('0.0098'));
    expect((stored.tables['accounts']!.single[2] as PluginIntCell).value, 90);
    final String? written = codec.encode(stored).config;
    expect(parseConfigLiteral(written!).value, parseConfigLiteral(config).value);
  });

  test('a configuration that is not the usual shape stays as text', () {
    final PluginSetup codec = setup('beancount_reds_plugins.rename_accounts.rename_accounts');
    final PluginStored stored = codec.decode("['nope']");
    expect(stored.structured, isFalse);
    expect(codec.encode(stored).config, "['nope']");
  });

  test('a double quote cannot be stored', () {
    final PluginSetup codec = setup('beancount_reds_plugins.daf.daf_mirror');
    expect(
      codec
          .encode(
            const PluginStored(
              text: <String, String>{'prefix': 'Assets:Giving', 'payee': 'Say "hi"'},
            ),
          )
          .error,
      pluginQuoteError,
    );
  });
}
