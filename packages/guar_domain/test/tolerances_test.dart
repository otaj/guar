// Tolerance inference shared by booking and the sellgains check.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

Amount units(String number, String currency, {int scale = 0}) => Amount(
  number: Decimal.parse(number),
  currency: Currency(name: currency),
  scale: scale,
);

Cost cost(String number, String currency) => Cost(
  number: Decimal.parse(number),
  currency: Currency(name: currency),
  date: BeanDate(year: 2020, month: 1, day: 1),
);

Origin origin() => SourceOrigin(BeanLocation(linenoBegin: 1, linenoEnd: 1));

Posting posting(String account, Amount units, {Cost? cost, Amount? price}) => Posting(
  origin: origin(),
  account: Account(name: account, type: AccountType.assets),
  units: units,
  cost: cost,
  price: price,
);

LedgerOptions options({bool inferCost = false, List<InferredTolerance> defaults = const <InferredTolerance>[]}) =>
    LedgerOptions(
      inferredToleranceMultiplier: OptionNumber(verbatim: '1.1', value: Decimal.parse('1.1')),
      inferToleranceFromCost: inferCost,
      inferredToleranceDefault: defaults,
    );

void main() {
  test('infers the tolerance from the written decimal places', () {
    final InferredTolerances tolerances = inferBookedTolerances(<Posting>[
      posting('Assets:Cash', units('10.00', 'USD', scale: 2)),
    ], options());
    // 0.01 * the 1.1 multiplier.
    expect(tolerances['USD'], Decimal.parse('0.011'));
  });

  test('takes the widest tolerance across postings', () {
    final InferredTolerances tolerances = inferBookedTolerances(<Posting>[
      posting('Assets:Cash', units('10.00', 'USD', scale: 2)),
      posting('Assets:Cash', units('10.0', 'USD', scale: 1)),
    ], options());
    // The widest written scale wins.
    expect(tolerances['USD'], Decimal.parse('0.11'));
  });

  test('applies a default preset to currencies seen in the postings', () {
    final InferredTolerances tolerances = inferBookedTolerances(
      <Posting>[
        posting('Assets:Cash', units('10', 'USD')),
      ],
      options(
        defaults: <InferredTolerance>[
          InferredTolerance(key: const CurrencyKey.all(), value: Decimal.parse('0.05')),
          InferredTolerance(
            key: CurrencyKey.currency(Currency(name: 'CAD')),
            value: Decimal.parse('0.02'),
          ),
        ],
      ),
    );
    // USD is seen, so the all-preset becomes its fallback; CAD is unseen and gets nothing.
    expect(tolerances['USD'], Decimal.parse('0.05'));
    expect(tolerances['CAD'], Decimal.parse('0.05'));
    expect(tolerances['EUR'], Decimal.parse('0.05'));
  });

  test('adds cost and price tolerances when infer_tolerance_from_cost is on', () {
    final InferredTolerances tolerances = inferBookedTolerances(<Posting>[
      posting(
        'Assets:Inv',
        units('-10.00', 'HOOL', scale: 2),
        cost: cost('400.00', 'USD'),
        price: Amount(
          number: Decimal.parse('401.00'),
          currency: Currency(name: 'USD'),
        ),
      ),
    ], options(inferCost: true));
    // Cost tolerance = min(0.011 * 400, 0.5) = 0.5; price adds min(0.011 * 401, 0.5) = 0.5.
    expect(tolerances['USD'], Decimal.parse('1.0'));
  });

  test('the min mode narrows to the tightest tolerance', () {
    final InferredTolerances tolerances = inferBookedTolerances(
      <Posting>[
        posting('Assets:Cash', units('10.00', 'USD', scale: 2)),
        posting('Assets:Cash', units('10.0', 'USD', scale: 1)),
      ],
      options(),
      mode: ToleranceMode.min,
    );
    expect(tolerances['USD'], Decimal.parse('0.011'));
  });
}
