// Port of beancount.plugins.sellgains tests.

import 'package:test/test.dart';

import 'support.dart';

const _header =
    'plugin "beancount.plugins.auto_accounts"\n'
    'plugin "beancount.plugins.sellgains"\n';

void main() {
  test('accepts a sale whose price matches the proceeds', () {
    expect(
      messages(
        '$_header'
        '1999-07-31 * "Sell"\n'
        '  Assets:US:Company:ESPP          -81 ADSK {26.3125 USD} @ 26.4375 USD\n'
        '  Assets:US:Company:Cash      2141.36 USD\n'
        '  Expenses:Financial:Fees        0.08 USD\n'
        '  Income:US:Company:ESPP:PnL\n',
      ),
      isEmpty,
    );
  });

  test('flags a sale whose proceeds disagree with the price', () {
    expect(
      messages(
        '$_header'
        '1999-07-31 * "Sell"\n'
        '  Assets:US:Company:ESPP          -81 ADSK {26.3125 USD} @ 26.4375 USD\n'
        '  Assets:US:Company:Cash      2141.36 USD\n'
        '  Expenses:Financial:Fees        1.08 USD\n'
        '  Income:US:Company:ESPP:PnL   -11.13 USD\n',
      ),
      contains(startsWith('Invalid price vs. proceeds/gains:')),
    );
  });

  test('accepts proceeds converted through another currency', () {
    expect(
      messages(
        '$_header'
        '1999-07-31 * "Sell"\n'
        '  Assets:US:Company:ESPP          -80 ADSK {26.50 USD} @ 27.50 USD\n'
        '  Expenses:Commissions           9.95 USD\n'
        '  Assets:US:Company:Cash      2433.39 CAD @ 0.9000 USD\n'
        '  Income:US:Company:ESPP:PnL   -80.00 USD\n',
      ),
      isEmpty,
    );
  });

  test('accepts a worthless lot sold at a zero price', () {
    expect(
      messages(
        '$_header'
        '1999-07-31 * "Sell"\n'
        '  Assets:US:Broker:Options     -8000 VTI180216C200 {2.50 USD} @ 0 USD\n'
        '  Income:US:Company:ESPP:PnL    20000 USD\n',
      ),
      isEmpty,
    );
  });

  test('ignores transactions whose lots carry no price', () {
    expect(
      messages(
        '$_header'
        '1999-07-31 * "Buy"\n'
        '  Assets:US:Company:ESPP          81 ADSK {26.3125 USD}\n'
        '  Assets:US:Company:Cash    -2131.3125 USD\n',
      ),
      isEmpty,
    );
  });
}
