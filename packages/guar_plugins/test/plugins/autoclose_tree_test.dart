// Port of beancount_reds_plugins.autoclose_tree tests.

import 'package:test/test.dart';

import 'support.dart';

const String _plugin = 'plugin "beancount_reds_plugins.autoclose_tree.autoclose_tree"\n';

void main() {
  test('empty entries', () {
    expect(booked(_plugin), isEmpty);
  });

  test('closes descendants of a closed account', () {
    expect(
      closes(
        booked(
          '$_plugin'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2015-01-01 close Assets:XBank\n',
        ),
      ),
      <String>['2015-01-01 Assets:XBank:AAPL', '2015-01-01 Assets:XBank'],
    );
  });

  test('leaves sibling trees untouched', () {
    expect(
      closes(
        booked(
          '$_plugin'
          '2014-01-01 open Assets:YBank\n'
          '2014-01-01 open Assets:YBank:AAPL\n'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2014-01-01 open Assets:XBank:AAPL:Fuji\n'
          '2014-01-01 open Assets:XBank:AAPL:Gala\n'
          '2014-01-01 open Assets:XBank:ORNG\n'
          '2014-01-01 open Assets:XBank:BANANA\n'
          '2015-01-01 close Assets:XBank\n',
        ),
      ),
      unorderedEquals(<dynamic>[
        '2015-01-01 Assets:XBank:AAPL',
        '2015-01-01 Assets:XBank:AAPL:Fuji',
        '2015-01-01 Assets:XBank:AAPL:Gala',
        '2015-01-01 Assets:XBank:ORNG',
        '2015-01-01 Assets:XBank:BANANA',
        '2015-01-01 Assets:XBank',
      ]),
    );
  });

  test('keeps an explicit earlier close and does not repeat it', () {
    expect(
      closes(
        booked(
          '$_plugin'
          '2014-01-01 open Assets:XBank\n'
          '2014-01-01 open Assets:XBank:AAPL\n'
          '2014-01-01 open Assets:XBank:AAPL:Fuji\n'
          '2015-01-01 close Assets:XBank:AAPL\n'
          '2016-01-01 close Assets:XBank\n',
        ),
      ),
      <String>['2015-01-01 Assets:XBank:AAPL:Fuji', '2015-01-01 Assets:XBank:AAPL', '2016-01-01 Assets:XBank'],
    );
  });

  test('only matches on full account components', () {
    expect(
      closes(
        booked(
          '$_plugin'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi\n'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi-CustomCash\n'
          '2017-11-10 open Liabilities:Credit-Cards:Spouse:Citi:Addon\n'
          '2018-11-10 close Liabilities:Credit-Cards:Spouse:Citi\n',
        ),
      ),
      <String>[
        '2018-11-10 Liabilities:Credit-Cards:Spouse:Citi:Addon',
        '2018-11-10 Liabilities:Credit-Cards:Spouse:Citi',
      ],
    );
  });

  test('drops the close of a parent that was never opened', () {
    expect(
      closes(
        booked(
          '$_plugin'
          '2017-11-10 open Assets:Brokerage:AAPL\n'
          '2017-11-10 open Assets:Brokerage:ORNG\n'
          '2018-11-10 close Assets:Brokerage\n',
        ),
      ),
      <String>['2018-11-10 Assets:Brokerage:AAPL', '2018-11-10 Assets:Brokerage:ORNG'],
    );
  });

  test('closes auto_accounts descendants of an unopened parent', () {
    expect(
      closes(
        booked(
          'plugin "beancount.plugins.auto_accounts"\n'
          '$_plugin'
          '2019-01-01 * "Transaction"\n'
          '  Expenses:Non-Retirement:Auto:Fit:Insurance -10 USD\n'
          '  Expenses:Non-Retirement:Auto:Fit:Gas\n'
          '\n'
          '2021-06-17 close Expenses:Non-Retirement:Auto:Fit\n',
        ),
      ),
      unorderedEquals(<dynamic>[
        '2021-06-17 Expenses:Non-Retirement:Auto:Fit:Insurance',
        '2021-06-17 Expenses:Non-Retirement:Auto:Fit:Gas',
        '2021-06-17 Expenses:Non-Retirement:Auto:Fit',
      ]),
    );
  });
}
