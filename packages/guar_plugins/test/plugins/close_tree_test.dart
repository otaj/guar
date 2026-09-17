// Port of beancount.plugins.close_tree tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('closes descendants of a closed account', () {
    expect(
      closes(
        booked(
          'plugin "beancount.plugins.close_tree"\n'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2015-01-01 close Assets:XBank\n',
        ),
      ),
      ['2015-01-01 Assets:XBank:AAPL', '2015-01-01 Assets:XBank'],
    );
  });

  test('leaves sibling trees untouched', () {
    expect(
      closes(
        booked(
          'plugin "beancount.plugins.close_tree"\n'
          '2014-01-01 open Assets:YBank\n'
          '2014-01-01 open Assets:YBank:AAPL\n'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2014-01-01 open Assets:XBank:ORNG\n'
          '2015-01-01 close Assets:XBank\n',
        ),
      ),
      ['2015-01-01 Assets:XBank:AAPL', '2015-01-01 Assets:XBank:ORNG', '2015-01-01 Assets:XBank'],
    );
  });

  test('keeps an explicit earlier close and does not repeat it', () {
    expect(
      closes(
        booked(
          'plugin "beancount.plugins.close_tree"\n'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2014-01-01 open Assets:XBank:AAPL:Fuji\n'
          '2015-01-01 close Assets:XBank:AAPL\n'
          '2016-01-01 close Assets:XBank\n',
        ),
      ),
      ['2015-01-01 Assets:XBank:AAPL:Fuji', '2015-01-01 Assets:XBank:AAPL', '2016-01-01 Assets:XBank'],
    );
  });

  test('drops the close of a parent that was never opened', () {
    final directives = booked(
      'plugin "beancount.plugins.close_tree"\n'
      '2017-11-10 open Assets:Brokerage:AAPL\n'
      '2017-11-10 open Assets:Brokerage:ORNG\n'
      '2018-11-10 close Assets:Brokerage\n',
    );
    expect(closes(directives), ['2018-11-10 Assets:Brokerage:AAPL', '2018-11-10 Assets:Brokerage:ORNG']);
  });

  test('only matches on full account components', () {
    expect(
      closes(
        booked(
          'plugin "beancount.plugins.close_tree"\n'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi\n'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi-CustomCash\n'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi:Addon\n'
          '2018-11-10 close Liabilities:Credit-Cards:Spouse:Citi\n',
        ),
      ),
      ['2018-11-10 Liabilities:Credit-Cards:Spouse:Citi:Addon', '2018-11-10 Liabilities:Credit-Cards:Spouse:Citi'],
    );
  });
}
