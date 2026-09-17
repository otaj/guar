// Account hierarchy and LedgerInventory lookup helpers.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  group('Account.isSubaccountOf', () {
    test('detects proper descendants', () {
      final food = Account(name: 'Expenses:Food', type: AccountType.expenses);
      final restaurant = Account(name: 'Expenses:Food:Restaurant', type: AccountType.expenses);
      final groceries = Account(name: 'Expenses:Food:Groceries', type: AccountType.expenses);
      final other = Account(name: 'Expenses:Transport', type: AccountType.expenses);

      expect(restaurant.isSubaccountOf(food), isTrue);
      expect(groceries.isSubaccountOf(food), isTrue);
      expect(food.isSubaccountOf(food), isFalse);
      expect(food.isSubaccountOf(restaurant), isFalse);
      expect(other.isSubaccountOf(food), isFalse);
      expect(restaurant.isSubaccountOf(other), isFalse);
    });

    test('requires a full component boundary', () {
      final food = Account(name: 'Expenses:Food', type: AccountType.expenses);
      final foodie = Account(name: 'Expenses:Foodie', type: AccountType.expenses);
      expect(foodie.isSubaccountOf(food), isFalse);
    });
  });

  group('AccountPrefixes.typeFor', () {
    const prefixes = AccountPrefixes();

    test('classifies by root prefix including the root itself', () {
      expect(prefixes.typeFor('Assets:Cash'), AccountType.assets);
      expect(prefixes.typeFor('Assets'), AccountType.assets);
      expect(prefixes.typeFor('Liabilities:Credit'), AccountType.liabilities);
      expect(prefixes.typeFor('Equity:Opening'), AccountType.equity);
      expect(prefixes.typeFor('Income:Salary'), AccountType.income);
      expect(prefixes.typeFor('Expenses:Food'), AccountType.expenses);
    });

    test('defaults unknown roots to assets', () {
      expect(prefixes.typeFor('Unknown:Foo'), AccountType.assets);
    });

    test('honors custom prefixes', () {
      const french = AccountPrefixes(assets: 'Actifs', expenses: 'Depenses');
      expect(french.typeFor('Actifs:Cash'), AccountType.assets);
      expect(french.typeFor('Depenses:Food'), AccountType.expenses);
      expect(french.typeFor('Expenses:Food'), AccountType.assets);
    });

    test('account builds a typed Account', () {
      final account = prefixes.account('Expenses:Food');
      expect(account.name, 'Expenses:Food');
      expect(account.type, AccountType.expenses);
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
      expect(underFood.currencyUnits(Currency(name: 'USD')), amount('35', 'USD'));
      expect(underFood.currencyUnits(Currency(name: 'EUR')), amount('15', 'EUR'));
    });
  });
}
