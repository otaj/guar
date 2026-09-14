// Account hierarchy and LedgerInventory lookup helpers.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  group('Account.isSubaccountOf', () {
    test('detects proper descendants', () {
      const food = Account(name: 'Expenses:Food', type: AccountType.expenses);
      const restaurant = Account(name: 'Expenses:Food:Restaurant', type: AccountType.expenses);
      const groceries = Account(name: 'Expenses:Food:Groceries', type: AccountType.expenses);
      const expenses = Account(name: 'Expenses', type: AccountType.expenses);
      const other = Account(name: 'Expenses:Transport', type: AccountType.expenses);

      expect(restaurant.isSubaccountOf(food), isTrue);
      expect(groceries.isSubaccountOf(food), isTrue);
      expect(restaurant.isSubaccountOf(expenses), isTrue);
      expect(food.isSubaccountOf(food), isFalse);
      expect(food.isSubaccountOf(restaurant), isFalse);
      expect(other.isSubaccountOf(food), isFalse);
      expect(restaurant.isSubaccountOf(other), isFalse);
    });

    test('requires a full component boundary', () {
      const food = Account(name: 'Expenses:Food', type: AccountType.expenses);
      const foodie = Account(name: 'Expenses:Foodie', type: AccountType.expenses);
      expect(foodie.isSubaccountOf(food), isFalse);
    });
  });

  group('LedgerInventory account lookup', () {
    final ledger = LedgerInventory()
        .addPosition(account('Expenses:Food', AccountType.expenses), position('10', 'USD'))
        .addPosition(account('Expenses:Food:Restaurant', AccountType.expenses), position('25', 'USD'))
        .addPosition(account('Expenses:Food:Groceries', AccountType.expenses), position('15', 'EUR'))
        .addPosition(account('Expenses:Transport', AccountType.expenses), position('40', 'USD'));

    test('inventoryFor returns only the explicit account', () {
      final food = ledger.inventoryFor(account('Expenses:Food', AccountType.expenses));
      expect(food?.positions, [position('10', 'USD')]);
      expect(ledger.inventoryFor(account('Expenses:Missing', AccountType.expenses)), isNull);
    });

    test('inventoryUnder aggregates the account and all subaccounts', () {
      final underFood = ledger.inventoryUnder(account('Expenses:Food', AccountType.expenses));
      expect(underFood.currencyUnits(const Currency(name: 'USD')), amount('35', 'USD'));
      expect(underFood.currencyUnits(const Currency(name: 'EUR')), amount('15', 'EUR'));

      final underExpenses = ledger.inventoryUnder(account('Expenses', AccountType.expenses));
      expect(underExpenses.currencyUnits(const Currency(name: 'USD')), amount('75', 'USD'));
      expect(underExpenses.currencyUnits(const Currency(name: 'EUR')), amount('15', 'EUR'));
    });
  });
}
