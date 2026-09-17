// Port of beancount_reds_plugins.effective_date tests.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

const _plugin = 'plugin "beancount_reds_plugins.effective_date.effective_date"\n';

void main() {
  test('empty entries', () {
    expect(booked(_plugin), isEmpty);
  });

  test('leaves transactions without effective dates unchanged', () {
    final source =
        '$_plugin'
        '2014-01-01 open Liabilities:Mastercard\n'
        '2014-01-01 open Expenses:Taxes:Federal\n'
        '2014-02-01 * "Estimated taxes for 2013"\n'
        '  Liabilities:Mastercard        -2000 USD\n'
        '  Expenses:Taxes:Federal\n';
    final txns = _txns(booked(source));
    expect(txns, hasLength(1));
    expect(txns.single.date.toString(), '2014-02-01');
  });

  test('books an earlier expense onto a holding account', () {
    final txns = _txns(
      booked(
        '$_plugin'
        '2014-01-01 open Liabilities:Mastercard\n'
        '2014-01-01 open Expenses:Taxes:Federal\n'
        '2014-02-01 * "Estimated taxes for 2013"\n'
        '  Liabilities:Mastercard        -2000 USD\n'
        '  Expenses:Taxes:Federal         2000 USD\n'
        '    effective_date: 2013-12-31\n',
      ),
    );
    expect(txns, hasLength(2));
    expect(txns[0].date.toString(), '2013-12-31');
    expect(txns[1].date.toString(), '2014-02-01');
    expect(txns[0].value.links, isNotEmpty);
    expect(txns[0].value.links.single.name, startsWith('edate-140201-'));
    expect(txns[0].value.links, txns[1].value.links);
  });

  test('splits multiple later expense postings', () {
    final directives = booked(
      '$_plugin'
      '2014-01-01 open Liabilities:Mastercard\n'
      '2014-01-01 open Expenses:Car:Insurance\n'
      '2014-02-01 * "Car insurance: 3 months"\n'
      '  Liabilities:Mastercard        -600 USD\n'
      '  Expenses:Car:Insurance         200 USD\n'
      '    effective_date: 2014-03-01\n'
      '  Expenses:Car:Insurance         200 USD\n'
      '    effective_date: 2014-04-01\n'
      '  Expenses:Car:Insurance         200 USD\n'
      '    effective_date: 2014-05-01\n',
    );
    expect(_txns(directives), hasLength(4));
    expect(opens(directives), contains('Assets:Hold:Expenses:Car:Insurance'));
  });

  test('errors when effective and actual dates are identical', () {
    expect(
      messages(
        '$_plugin'
        '2014-01-01 open Liabilities:Mastercard\n'
        '2014-01-01 open Expenses:Taxes:Federal\n'
        '2014-02-01 * "Estimated taxes for 2013"\n'
        '  Liabilities:Mastercard        -2000 USD\n'
        '  Expenses:Taxes:Federal         2000 USD\n'
        '    effective_date: 2014-02-01\n',
      ),
      contains('Effective and actual dates are identical'),
    );
  });
}

List<({BeanDate date, Transaction value})> _txns(List<Directive> directives) => [
  for (final directive in directives)
    if (directive.body case TransactionBody(:final value)) (date: directive.date, value: value),
];
