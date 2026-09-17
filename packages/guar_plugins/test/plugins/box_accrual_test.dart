// Port of beancount_reds_plugins.box_accrual tests.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('splits a multi-year capital loss across calendar years', () {
    final directives = booked(
      'plugin "beancount.plugins.auto_accounts"\n'
      'plugin "beancount_reds_plugins.box_accrual.box_accrual"\n'
      '2025-09-25 * "SPX 18DEC26" "Box Borrow 100k"\n'
      '  synthetic_loan_expiry: 2026-12-18\n'
      '  Assets:Investments:Taxable:IBKR:USD                                     95000 USD\n'
      '  Expenses:Fees-and-Charges:Brokerage-Fees:Taxable:IBKR                       6 USD\n'
      '  Liabilities:Loans:BoxSpreadLoans                                      -90012 USD\n'
      '  Income:Investments:Taxable:BoxTrades:Capital-Losses                    -4994 USD\n',
    );
    final txn = [
      for (final directive in directives)
        if (directive.body case TransactionBody(:final value)) value,
    ].single;
    final losses = [
      for (final posting in txn.postings)
        if (posting.account.name.endsWith(':Capital-Losses')) posting,
    ];
    expect(losses, hasLength(2));
    expect(losses[0].units.number + losses[1].units.number, Decimal.parse('-4994.00'));
    expect(metaDate(losses[0].meta), BeanDate(year: 2025, month: 12, day: 31));
    expect(metaDate(losses[1].meta), BeanDate(year: 2026, month: 12, day: 18));
    expect(losses[0].units.number, Decimal.parse('-1087.58'));
    expect(losses[1].units.number, Decimal.parse('-3906.42'));
    expect(losses[0].cost, isNull);
    expect(losses[0].price, isNull);
  });
}

BeanDate? metaDate(Meta meta) {
  for (final entry in meta.entries) {
    if (entry.key == 'effective_date') {
      return switch (entry.value) {
        MetaDate(:final value) => value,
        _ => null,
      };
    }
  }
  return null;
}
