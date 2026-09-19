// Fava custom "budget" directives become first-class BudgetBody after booking.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

Ledger _book(String source) => Book().process(const p.BeancountParser().parse(source, filename: 'budget.beancount'));

List<Directive> _directives(String source) {
  final Ledger ledger = _book(source);
  return switch (ledger) {
    LedgerDirectives(:final List<Directive> directives) => directives,
    LedgerErrors(:final List<ProcessingError> errors) => throw TestFailure(
      errors.map((ProcessingError error) => error.message).join('\n'),
    ),
  };
}

BeanDate _d(int year, int month, int day) => BeanDate(year: year, month: month, day: day);

Amount? _named(List<Amount> amounts, String currency) {
  for (final Amount amount in amounts) {
    if (amount.currency.name == currency) return amount;
  }
  return null;
}

void main() {
  test('promotes Fava budget customs to BudgetBody', () {
    final List<BudgetBody> bodies = _directives('''
2012-01-01 custom "budget" Expenses:Coffee       "daily"         4.00 EUR
2013-01-01 custom "budget" Expenses:Books        "weekly"       20.00 EUR
2014-02-10 custom "budget" Expenses:Groceries    "monthly"      40.00 EUR
2015-05-01 custom "budget" Expenses:Electricity  "quarterly"    85.00 EUR
2016-06-01 custom "budget" Expenses:Holiday      "yearly"     2500.00 EUR
''').map((Directive directive) => directive.body).whereType<BudgetBody>().toList();

    expect(bodies, hasLength(5));
    expect(
      bodies
          .map(
            (BudgetBody body) =>
                (body.account.name, body.interval, body.amount.number, body.amount.currency.name, body.amount.scale),
          )
          .toList(),
      <(String, BudgetInterval, Decimal, String, int)>[
        ('Expenses:Coffee', BudgetInterval.daily, Decimal.parse('4.00'), 'EUR', 2),
        ('Expenses:Books', BudgetInterval.weekly, Decimal.parse('20.00'), 'EUR', 2),
        ('Expenses:Groceries', BudgetInterval.monthly, Decimal.parse('40.00'), 'EUR', 2),
        ('Expenses:Electricity', BudgetInterval.quarterly, Decimal.parse('85.00'), 'EUR', 2),
        ('Expenses:Holiday', BudgetInterval.yearly, Decimal.parse('2500.00'), 'EUR', 2),
      ],
    );
  });

  test('accepts Fava interval names and short aliases', () {
    const List<(String, BudgetInterval)> cases = <(String, BudgetInterval)>[
      ('daily', BudgetInterval.daily),
      ('week', BudgetInterval.weekly),
      ('MONTHLY', BudgetInterval.monthly),
      ('quarter', BudgetInterval.quarterly),
      ('year', BudgetInterval.yearly),
    ];
    for (final (String name, BudgetInterval interval) in cases) {
      final BudgetBody body =
          _directives('2016-01-01 custom "budget" Expenses:Books "$name" 100.00 EUR').single.body as BudgetBody;
      expect(body.interval, interval, reason: name);
    }
  });

  test('turns off a budget without an amount', () {
    for (final String name in <String>['off', 'NONE']) {
      final BudgetOffBody body =
          _directives('2016-06-01 custom "budget" Expenses:Books "$name"').single.body as BudgetOffBody;
      expect(body.account.name, 'Expenses:Books', reason: name);
      expect(body.currency, isNull, reason: name);
    }
  });

  test('turns off a single currency when one is attached', () {
    final BudgetOffBody body =
        _directives('2016-06-01 custom "budget" Expenses:Books "off" EUR').single.body as BudgetOffBody;
    expect(body.account.name, 'Expenses:Books');
    expect(body.currency?.name, 'EUR');
  });

  test('turns off a currency with none and an inert amount', () {
    final BudgetOffBody body =
        _directives('2016-07-01 custom "budget" Expenses:Food "none" 0 USD').single.body as BudgetOffBody;
    expect(body.account.name, 'Expenses:Food');
    expect(body.currency?.name, 'USD');
  });

  test('treats a none or off amount as an inert currency name', () {
    for (final String source in <String>[
      '2016-07-01 custom "budget" Expenses:Food "none" 10 USD',
      '2016-07-01 custom "budget" Expenses:Food "off" 10.00 EUR',
    ]) {
      final BudgetOffBody body = _directives(source).single.body as BudgetOffBody;
      expect(body.account.name, 'Expenses:Food', reason: source);
      expect(body.currency?.name, source.contains('USD') ? 'USD' : 'EUR', reason: source);
    }
  });

  test('a zero amount with a real interval is a budget of zero', () {
    final BudgetBody body =
        _directives('2016-07-01 custom "budget" Expenses:Food "monthly" 0 USD').single.body as BudgetBody;
    expect(body.account.name, 'Expenses:Food');
    expect(body.interval, BudgetInterval.monthly);
    expect(body.amount.number, Decimal.zero);
    expect(body.amount.currency.name, 'USD');
  });

  test('promotes a quoted root account to a budget', () {
    final BudgetBody body =
        _directives('2016-01-01 custom "budget" "Expenses" "monthly" 9000 USD').single.body as BudgetBody;
    expect(body.account.name, 'Expenses');
    expect(body.interval, BudgetInterval.monthly);
    expect(body.amount.number, Decimal.parse('9000'));
    expect(body.amount.currency.name, 'USD');
  });

  test('leaves malformed budget customs as CustomBody', () {
    final List<DirectiveBody> bodies = _directives('''
2016-06-01 custom "budget" Expenses:Groceries "asdfasdf" 10.00 EUR
2016-01-01 custom "budget" Expenses:Groceries "weekly"
2016-06-01 custom "budget" Expenses:Groceries "off" EUR "extra"
2016-06-01 custom "budget" Expenses:Groceries 10.00 EUR
2013-05-18 custom "budget" "weekly < 1000.00 USD" 2016-02-28 TRUE 43.03 USD 23
''').map((Directive directive) => directive.body).toList();

    expect(bodies, everyElement(isA<CustomBody>()));
    expect(bodies.whereType<CustomBody>().map((CustomBody body) => body.type).toSet(), <String>{'budget'});
  });

  test('leaves non-budget customs unchanged', () {
    final CustomBody body = _directives('2014-07-09 custom "fava-option" "interval" "month"').single.body as CustomBody;
    expect(body.type, 'fava-option');
  });

  test('none with an inert amount stops that currency from the date', () {
    final BudgetMap map = BudgetMap.build(
      _directives('''
2016-01-01 custom "budget" Expenses:Books "daily" 10.00 EUR
2016-01-01 custom "budget" Expenses:Books "weekly" 70.00 USD
2016-06-01 custom "budget" Expenses:Books "none" 0 EUR
'''),
    );
    expect(
      _named(map.allowed('Expenses:Books', _d(2016, 5, 31), _d(2016, 6, 1)), 'EUR')!.number,
      Decimal.parse('10.00'),
    );
    expect(_named(map.allowed('Expenses:Books', _d(2016, 5, 31), _d(2016, 6, 1)), 'USD'), isNotNull);
    expect(_named(map.allowed('Expenses:Books', _d(2016, 6, 1), _d(2016, 6, 2)), 'EUR'), isNull);
    expect(_named(map.allowed('Expenses:Books', _d(2016, 6, 1), _d(2016, 6, 2)), 'USD'), isNotNull);
  });
}
