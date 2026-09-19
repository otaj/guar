// Port of beancount.plugins.check_average_cost tests.

import 'package:test/test.dart';

import 'support.dart';

const String _setup =
    'plugin "beancount.plugins.check_average_cost"\n'
    '2018-01-01 open Assets:US:Cash\n'
    '2018-01-01 open Assets:US:Retirement         "NONE"\n'
    '2018-01-01 open Income:US:Retirement:Pnl\n'
    '2018-05-01 * "Buy"\n'
    '  Assets:US:Retirement            100 MSFT {56.00 USD}\n'
    '  Assets:US:Retirement            100 MSFT {60.00 USD}\n'
    '  Assets:US:Cash               -11600 USD\n';

String _sell(String narration, String cost) =>
    '$_setup'
    '2018-09-01 * "$narration"\n'
    '  Assets:US:Retirement            -50 MSFT {$cost USD} @ 61.00 USD\n'
    '  Assets:US:Cash              3050.00 USD\n'
    '  Income:US:Retirement:Pnl\n';

void main() {
  test('accepts a reduction at the average cost', () {
    expect(messages(_sell('Precisely equal.', '58.00')), isEmpty);
  });

  test('accepts reductions inside the default tolerance band', () {
    expect(messages(_sell('Above but within range.', '58.00 * 1.01')), isEmpty);
    expect(messages(_sell('Below but within range.', '58.00 * 0.99')), isEmpty);
  });

  test('flags reductions outside the default tolerance band', () {
    expect(
      messages(_sell('Above and out of range.', '58.00 * 1.02')),
      contains(startsWith('Cost basis on reducing posting is too far from the average cost')),
    );
    expect(
      messages(_sell('Below and out of range.', '58.00 * 0.98')),
      contains(startsWith('Cost basis on reducing posting is too far from the average cost')),
    );
  });

  test('widens the band when configured with a float', () {
    expect(
      messages(
        _sell('Above and out of range.', '58.00 * 1.02').replaceFirst(
          'plugin "beancount.plugins.check_average_cost"',
          'plugin "beancount.plugins.check_average_cost" "0.05"',
        ),
      ),
      isEmpty,
    );
  });

  test('rejects a configuration that is not a float', () {
    expect(
      messages(
        _sell('Precisely equal.', '58.00').replaceFirst(
          'plugin "beancount.plugins.check_average_cost"',
          'plugin "beancount.plugins.check_average_cost" "1"',
        ),
      ),
      <String>['Invalid configuration for check_average_cost: must be a float'],
    );
  });

  test('ignores accounts that are not booked with NONE', () {
    expect(
      messages(
        'plugin "beancount.plugins.check_average_cost"\n'
        '2018-01-01 open Assets:US:Cash\n'
        '2018-01-01 open Assets:US:Retirement\n'
        '2018-05-01 * "Buy"\n'
        '  Assets:US:Retirement            100 MSFT {56.00 USD}\n'
        '  Assets:US:Cash               -5600 USD\n'
        '2018-09-01 * "Sell"\n'
        '  Assets:US:Retirement           -100 MSFT {56.00 USD}\n'
        '  Assets:US:Cash                 5600 USD\n',
      ),
      isEmpty,
    );
  });
}
