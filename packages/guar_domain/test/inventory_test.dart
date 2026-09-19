// Ports of beancount.core.inventory_test for strict lot-matching Inventory.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  group('Inventory', () {
    test('empty constructor', () {
      const Inventory inv = Inventory();
      expect(inv.isEmpty, isTrue);
      expect(inv.length, 0);
    });

    test('addAmount coalesces same currency without cost', () {
      Inventory inv = const Inventory();
      InventoryAdd add = inv.addAmount(amount('100', 'USD'));
      expect(add.result, MatchResult.created);
      inv = add.inventory;
      expect(inv.currencyUnits(Currency(name: 'USD')), amount('100', 'USD'));

      add = inv.addAmount(amount('25.01', 'USD'));
      expect(add.result, MatchResult.augmented);
      inv = add.inventory;
      expect(inv.currencyUnits(Currency(name: 'USD')), amount('125.01', 'USD'));

      add = inv.addAmount(amount('-12.73', 'USD'));
      expect(add.result, MatchResult.reduced);
      inv = add.inventory;
      expect(inv.currencyUnits(Currency(name: 'USD')), amount('112.28', 'USD'));

      add = inv.addAmount(amount('-120', 'USD'));
      expect(add.result, MatchResult.reduced);
      inv = add.inventory;
      expect(inv.currencyUnits(Currency(name: 'USD')), amount('-7.72', 'USD'));
    });

    test('addAmount removes a lot that reaches zero', () {
      final Inventory inv = const Inventory().addAmount(amount('10', 'USD')).inventory;
      final InventoryAdd add = inv.addAmount(amount('-10', 'USD'));
      expect(add.result, MatchResult.reduced);
      expect(add.inventory.isEmpty, isTrue);
    });

    test('lots with different costs stay distinct', () {
      final BeanDate date1 = BeanDate(year: 2014, month: 6, day: 15);
      final BeanDate date2 = BeanDate(year: 2015, month: 7, day: 14);
      Inventory inv = const Inventory();
      inv = inv.addAmount(amount('2.2', 'HOOL'), cost: cost('532.43', 'USD', date1)).inventory;
      inv = inv.addAmount(amount('2.3', 'HOOL'), cost: cost('564.00', 'USD', date2)).inventory;
      inv = inv.addAmount(amount('3.413', 'EUR')).inventory;
      expect(inv.length, 3);
      expect(inv.currencyUnits(Currency(name: 'HOOL')), amount('4.5', 'HOOL'));
      expect(inv.currencyUnits(Currency(name: 'EUR')), amount('3.413', 'EUR'));
    });

    test('equality ignores position order', () {
      final Inventory left = const Inventory()
          .addAmount(amount('100', 'USD'))
          .inventory
          .addAmount(amount('100', 'CAD'))
          .inventory;
      final Inventory right = const Inventory()
          .addAmount(amount('100', 'CAD'))
          .inventory
          .addAmount(amount('100', 'USD'))
          .inventory;
      expect(left, right);
    });

    test('neg and mul', () {
      final Inventory inv = const Inventory()
          .addAmount(amount('10', 'USD'))
          .inventory
          .addAmount(amount('1.5', 'JPY'))
          .inventory;
      expect((-inv).currencyUnits(Currency(name: 'USD')), amount('-10', 'USD'));
      expect((inv * Decimal.parse('3')).currencyUnits(Currency(name: 'USD')), amount('30', 'USD'));
    });

    test('isMixed detects opposite signs in one currency', () {
      final BeanDate date = BeanDate(year: 2014, month: 1, day: 1);
      final Inventory long = const Inventory()
          .addAmount(amount('100', 'HOOL'), cost: cost('250', 'USD', date))
          .inventory
          .addAmount(amount('101', 'HOOL'), cost: cost('251', 'USD', date))
          .inventory;
      expect(long.isMixed, isFalse);
      final Inventory mixed = long.addAmount(amount('-1', 'HOOL'), cost: cost('252', 'USD', date)).inventory;
      expect(mixed.isMixed, isTrue);
    });

    test('zero amount is ignored', () {
      final Inventory inv = const Inventory().addAmount(amount('10', 'USD')).inventory;
      final InventoryAdd add = inv.addAmount(amount('0', 'USD'));
      expect(add.result, MatchResult.ignored);
      expect(add.inventory, inv);
    });
  });

  group('LedgerInventory cash holdings', () {
    test('balance fixture holdings', () {
      final LedgerInventory ledger = const LedgerInventory()
          .addPosition(account('Assets:Bank:Current', AccountType.assets), position('-5.00', 'NZD'))
          .addPosition(account('Assets:Bank:Savings', AccountType.assets), position('5000.00', 'NZD'))
          .addPosition(account('Expenses:Entertainment', AccountType.expenses), position('850.00', 'NZD'))
          .addPosition(account('Expenses:Groceries', AccountType.expenses), position('155.00', 'NZD'))
          .addPosition(account('Income:Unknown', AccountType.income), position('-6000.00', 'NZD'));

      expect(
        ledger.accounts.map((AccountInventory e) => (e.account.name, e.inventory.positions.single.units)).toList(),
        <(String, Amount)>[
          ('Assets:Bank:Current', amount('-5.00', 'NZD')),
          ('Assets:Bank:Savings', amount('5000.00', 'NZD')),
          ('Expenses:Entertainment', amount('850.00', 'NZD')),
          ('Expenses:Groceries', amount('155.00', 'NZD')),
          ('Income:Unknown', amount('-6000.00', 'NZD')),
        ],
      );
    });

    test('simple fixture holdings including multi-currency account', () {
      final LedgerInventory ledger = const LedgerInventory()
          .addPosition(account('Assets:Bank:Current', AccountType.assets), position('-100.78', 'NZD'))
          .addPosition(account('Assets:Bank:UK', AccountType.assets), position('-5.00', 'GBP'))
          .addPosition(account('Expenses:Donations', AccountType.expenses), position('10.00', 'NZD'))
          .addPosition(account('Expenses:Donations:Other', AccountType.expenses), position('20.00', 'NZD'))
          .addPosition(
            account('Expenses:Entertainment:Drinks-and-snacks', AccountType.expenses),
            position('48.00', 'NZD'),
          )
          .addPosition(account('Expenses:Groceries', AccountType.expenses), position('5.00', 'GBP'))
          .addPosition(account('Expenses:Groceries', AccountType.expenses), position('27.50', 'NZD'))
          .addPosition(account('Income:Unknown', AccountType.income), position('-4.72', 'NZD'));

      final AccountInventory groceries = ledger.accounts.singleWhere(
        (AccountInventory e) => e.account.name == 'Expenses:Groceries',
      );
      expect(groceries.inventory.positions.map((Position pos) => pos.units).toList(), <Amount>[
        amount('5.00', 'GBP'),
        amount('27.50', 'NZD'),
      ]);
      expect(ledger.accounts.length, 7);
    });
  });
}
