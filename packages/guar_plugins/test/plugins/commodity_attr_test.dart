// Port of beancount.plugins.commodity_attr tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags missing and out-of-enum attributes', () {
    expect(
      messages(
        'plugin "beancount.plugins.commodity_attr" "{\n'
        "  'strategy': ['bigtech', 'bonds'],\n"
        '}"\n'
        '2018-08-02 commodity AAPL\n'
        '  strategy: "bigtech"\n'
        '2018-08-02 commodity BND\n'
        '  strategy: "bonds"\n'
        '2018-08-02 commodity BNDX\n'
        '2018-08-02 commodity VNQ\n'
        '  strategy: "bond"\n',
      ),
      <String>[
        "Missing attribute 'strategy' for Commodity directive BNDX",
        "Invalid value 'bond' for attribute strategy, Commodity directive VNQ; valid options: bigtech, bonds",
      ],
    );
  });

  test('checks existence only when the valid values are None', () {
    expect(
      messages(
        'plugin "beancount.plugins.commodity_attr" "{\n'
        "  'strategy': None,\n"
        '}"\n'
        '2018-08-02 commodity AAPL\n'
        '  strategy: "bigtech"\n'
        '2018-08-02 commodity BND\n',
      ),
      <String>["Missing attribute 'strategy' for Commodity directive BND"],
    );
  });

  test('rejects a configuration that is not a dict', () {
    expect(
      messages(
        'plugin "beancount.plugins.commodity_attr" "[1, 2]"\n'
        '2018-08-02 commodity AAPL\n',
      ),
      <String>['Invalid configuration for commodity_attr plugin; skipping.'],
    );
  });
}
