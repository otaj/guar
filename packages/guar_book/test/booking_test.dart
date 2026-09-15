// Booking of complete and interpolated cash transactions.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

p.ParsedDirective open(String account, {int line = 1}) => p.ParsedDirective(
  location: p.BeanLocation(linenoBegin: line, linenoEnd: line),
  date: p.BeanDate(year: 2020, month: 1, day: 1),
  body: p.DirectiveBody.open(account: p.Account(name: account)),
);

void main() {
  test('complete cash transaction passes through with defaults', () {
    final parsed = p.ParsedLedger.directives(
      directives: [
        open('Assets:Cash'),
        open('Expenses:Food', line: 2),
        p.ParsedDirective(
          location: p.BeanLocation(linenoBegin: 3, linenoEnd: 5),
          date: p.BeanDate(year: 2020, month: 2, day: 1),
          body: p.DirectiveBody.transaction(
            p.ParsedTransaction(
              flag: const p.Flag.special(p.SpecialFlag.asterisk),
              narration: 'lunch',
              postings: [
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 4, linenoEnd: 4),
                  account: p.Account(name: 'Expenses:Food'),
                  units: p.IncompleteAmount(
                    number: p.BeanNumber(verbatim: '10.00', resolved: Decimal.parse('10.00')),
                    currency: p.Currency(name: 'USD'),
                  ),
                ),
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 5, linenoEnd: 5),
                  account: p.Account(name: 'Assets:Cash'),
                  units: p.IncompleteAmount(
                    number: p.BeanNumber(verbatim: '-10.00', resolved: Decimal.parse('-10.00')),
                    currency: p.Currency(name: 'USD'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final ledger = Book().process(parsed);
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final directives = (ledger as LedgerDirectives).directives;
    final txn = directives.whereType<Directive>().map((d) => d.body).whereType<TransactionBody>().single.value;
    expect(txn.postings, hasLength(2));
    expect(txn.postings.first.units.number, Decimal.parse('10.00'));
    expect(txn.postings.first.account.type, AccountType.expenses);
  });

  test('interpolates a single elided posting', () {
    final parsed = p.ParsedLedger.directives(
      directives: [
        open('Assets:Cash'),
        open('Expenses:Food', line: 2),
        p.ParsedDirective(
          location: p.BeanLocation(linenoBegin: 3, linenoEnd: 5),
          date: p.BeanDate(year: 2020, month: 2, day: 1),
          body: p.DirectiveBody.transaction(
            p.ParsedTransaction(
              flag: const p.Flag.special(p.SpecialFlag.asterisk),
              narration: 'lunch',
              postings: [
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 4, linenoEnd: 4),
                  account: p.Account(name: 'Expenses:Food'),
                  units: p.IncompleteAmount(
                    number: p.BeanNumber(verbatim: '12.50', resolved: Decimal.parse('12.50')),
                    currency: p.Currency(name: 'USD'),
                  ),
                ),
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 5, linenoEnd: 5),
                  account: p.Account(name: 'Assets:Cash'),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final ledger = Book().process(parsed);
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final txn = (ledger as LedgerDirectives).directives.map((d) => d.body).whereType<TransactionBody>().single.value;
    expect(txn.postings.last.units.number, Decimal.parse('-12.50'));
    expect(txn.postings.last.units.currency.name, 'USD');
  });

  test('converts total cost to per-unit cost', () {
    final parsed = p.ParsedLedger.directives(
      directives: [
        open('Assets:Shares'),
        open('Assets:Cash', line: 2),
        p.ParsedDirective(
          location: p.BeanLocation(linenoBegin: 3, linenoEnd: 5),
          date: p.BeanDate(year: 2020, month: 3, day: 1),
          body: p.DirectiveBody.transaction(
            p.ParsedTransaction(
              flag: const p.Flag.special(p.SpecialFlag.asterisk),
              narration: 'buy',
              postings: [
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 4, linenoEnd: 4),
                  account: p.Account(name: 'Assets:Shares'),
                  units: p.IncompleteAmount(
                    number: p.BeanNumber(verbatim: '10', resolved: Decimal.fromInt(10)),
                    currency: p.Currency(name: 'HOOL'),
                  ),
                  cost: p.ParsedCost(
                    numberTotal: p.BeanNumber(verbatim: '1000.00', resolved: Decimal.parse('1000.00')),
                    currency: p.Currency(name: 'USD'),
                  ),
                ),
                p.ParsedPosting(
                  location: p.BeanLocation(linenoBegin: 5, linenoEnd: 5),
                  account: p.Account(name: 'Assets:Cash'),
                  units: p.IncompleteAmount(
                    number: p.BeanNumber(verbatim: '-1000.00', resolved: Decimal.parse('-1000.00')),
                    currency: p.Currency(name: 'USD'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final ledger = Book().process(parsed);
    expect(ledger, isA<LedgerDirectives>(), reason: ledger.toString());
    final txn = (ledger as LedgerDirectives).directives.map((d) => d.body).whereType<TransactionBody>().single.value;
    expect(txn.postings.first.cost!.number, Decimal.parse('100.00'));
    expect(txn.postings.first.cost!.currency.name, 'USD');
    expect(txn.postings.first.cost!.date, BeanDate(year: 2020, month: 3, day: 1));
  });
}
