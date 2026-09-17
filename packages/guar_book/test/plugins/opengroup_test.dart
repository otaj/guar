// Port of beancount_reds_plugins.opengroup tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const _plugin = 'plugin "beancount_reds_plugins.opengroup.opengroup" "{}"\n';

void main() {
  test('empty entries', () {
    expect(booked(_plugin), isEmpty);
  });

  test('opens income leaves for listed tickers', () {
    expect(
      _openLines(
        booked(
          '$_plugin'
          '2000-01-01 open Assets:Investments:Taxable:Midelity PARENT\n'
          '  opengroup_commodity_leaves_income: "ABC,DEFGH"\n',
        ),
      ),
      containsAll([
        'Assets:Investments:Taxable:Midelity PARENT',
        'Income:Investments:Taxable:Capital-Gains:Midelity:ABC USD',
        'Income:Investments:Taxable:Dividends:Midelity:ABC USD',
        'Income:Investments:Taxable:Interest:Midelity:ABC USD',
        'Income:Investments:Taxable:Capital-Gains:Midelity:DEFGH USD',
        'Income:Investments:Taxable:Dividends:Midelity:DEFGH USD',
        'Income:Investments:Taxable:Interest:Midelity:DEFGH USD',
      ]),
    );
  });

  test('opens asset leaves plus income accounts', () {
    expect(
      _openLines(
        booked(
          '$_plugin'
          '2000-01-01 open Assets:Investments:Taxable:Midelity PARENT\n'
          '  opengroup_commodity_leaves_income_and_asset: "ABC,DEFGH"\n',
        ),
      ),
      containsAll([
        'Assets:Investments:Taxable:Midelity:ABC ABC',
        'Assets:Investments:Taxable:Midelity:DEFGH DEFGH',
        'Income:Investments:Taxable:Dividends:Midelity:ABC USD',
      ]),
    );
  });
}

List<String> _openLines(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case OpenBody(:final account, :final currencies))
      currencies.isEmpty ? account.name : '${account.name} ${currencies.map((c) => c.name).join(',')}',
];
