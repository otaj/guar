// Fava custom "budget" directives become first-class BudgetBody after booking.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

Ledger _book(String source) => Book().process(p.BeancountParser().parse(source, filename: 'budget.beancount'));

List<Directive> _directives(String source) {
  final ledger = _book(source);
  return switch (ledger) {
    LedgerDirectives(:final directives) => directives,
    LedgerErrors(:final errors) => throw TestFailure(errors.map((error) => error.message).join('\n')),
  };
}

void main() {
  test('promotes Fava budget customs to BudgetBody', () {
    final bodies = _directives('''
2012-01-01 custom "budget" Expenses:Coffee       "daily"         4.00 EUR
2013-01-01 custom "budget" Expenses:Books        "weekly"       20.00 EUR
2014-02-10 custom "budget" Expenses:Groceries    "monthly"      40.00 EUR
2015-05-01 custom "budget" Expenses:Electricity  "quarterly"    85.00 EUR
2016-06-01 custom "budget" Expenses:Holiday      "yearly"     2500.00 EUR
''').map((directive) => directive.body).whereType<BudgetBody>().toList();

    expect(bodies, hasLength(5));
    expect(
      bodies
          .map(
            (body) =>
                (body.account.name, body.interval, body.amount.number, body.amount.currency.name, body.amount.scale),
          )
          .toList(),
      [
        ('Expenses:Coffee', BudgetInterval.daily, Decimal.parse('4.00'), 'EUR', 2),
        ('Expenses:Books', BudgetInterval.weekly, Decimal.parse('20.00'), 'EUR', 2),
        ('Expenses:Groceries', BudgetInterval.monthly, Decimal.parse('40.00'), 'EUR', 2),
        ('Expenses:Electricity', BudgetInterval.quarterly, Decimal.parse('85.00'), 'EUR', 2),
        ('Expenses:Holiday', BudgetInterval.yearly, Decimal.parse('2500.00'), 'EUR', 2),
      ],
    );
  });

  test('accepts Fava interval names and short aliases', () {
    const cases = [
      ('daily', BudgetInterval.daily),
      ('week', BudgetInterval.weekly),
      ('MONTHLY', BudgetInterval.monthly),
      ('quarter', BudgetInterval.quarterly),
      ('year', BudgetInterval.yearly),
    ];
    for (final (name, interval) in cases) {
      final body =
          _directives('2016-01-01 custom "budget" Expenses:Books "$name" 100.00 EUR').single.body as BudgetBody;
      expect(body.interval, interval, reason: name);
    }
  });

  test('leaves malformed budget customs as CustomBody', () {
    final bodies = _directives('''
2016-06-01 custom "budget" Expenses:Groceries "asdfasdf" 10.00 EUR
2016-01-01 custom "budget" Expenses:Groceries "weekly"
2016-06-01 custom "budget" Expenses:Groceries 10.00 EUR
2013-05-18 custom "budget" "weekly < 1000.00 USD" 2016-02-28 TRUE 43.03 USD 23
''').map((directive) => directive.body).toList();

    expect(bodies, everyElement(isA<CustomBody>()));
    expect(bodies.whereType<CustomBody>().map((body) => body.type).toSet(), {'budget'});
  });

  test('leaves non-budget customs unchanged', () {
    final body = _directives('2014-07-09 custom "fava-option" "interval" "month"').single.body as CustomBody;
    expect(body.type, 'fava-option');
  });
}
