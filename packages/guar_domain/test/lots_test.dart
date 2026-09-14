// Booked lots on a LedgerInventory from the costs-and-prices fixture.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  test('costs-and-prices fixture lots', () {
    final ledger = LedgerInventory()
        .addPosition(account('Assets:NZ:Cash', AccountType.assets), position('-638.86', 'NZD'))
        .addPosition(
          account('Assets:Shares:IBM', AccountType.assets),
          position('5', 'IBM', cost: cost('300.00', 'NZD', const BeanDate(year: 2025, month: 3, day: 1))),
        )
        .addPosition(
          account('Assets:Shares:IBM', AccountType.assets),
          position(
            '3',
            'IBM',
            cost: cost('303.33333333333333333333333333', 'NZD', const BeanDate(year: 2025, month: 4, day: 1)),
          ),
        )
        .addPosition(
          account('Assets:Shares:IBM', AccountType.assets),
          position('3', 'IBM', cost: cost('302.00', 'NZD', const BeanDate(year: 2025, month: 4, day: 5))),
        )
        .addPosition(account('Assets:UK:Cash', AccountType.assets), position('-1394.00', 'GBP'));

    expect(ledger.accounts.map((e) => e.account.name).toList(), [
      'Assets:NZ:Cash',
      'Assets:Shares:IBM',
      'Assets:UK:Cash',
    ]);

    final ibm = ledger.accounts.singleWhere((e) => e.account.name == 'Assets:Shares:IBM').inventory;
    expect(ibm.length, 3);
    expect(ibm.currencyUnits(const Currency(name: 'IBM')), amount('11', 'IBM'));
    expect(ibm.positions.map((p) => (p.units, p.cost)).toSet(), {
      (amount('5', 'IBM'), cost('300.00', 'NZD', const BeanDate(year: 2025, month: 3, day: 1))),
      (amount('3', 'IBM'), cost('303.33333333333333333333333333', 'NZD', const BeanDate(year: 2025, month: 4, day: 1))),
      (amount('3', 'IBM'), cost('302.00', 'NZD', const BeanDate(year: 2025, month: 4, day: 5))),
    });
  });
}
