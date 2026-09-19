// Ports of beancount.core.prices_test for PriceMap.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

Directive price(BeanDate date, String base, String rate, String quote) => Directive(
  origin: Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1)),
  date: date,
  body: DirectiveBody.price(
    currency: Currency(name: base),
    amount: amount(rate, quote),
  ),
);

void main() {
  group('PriceMap', () {
    test('build keeps last price on the same date and stores inverse', () {
      final PriceMap map = PriceMap.build(<Directive>[
        price(BeanDate(year: 2013, month: 6, day: 1), 'USD', '1.10', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 2), 'USD', '1.11', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 2), 'USD', '1.12', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 2), 'USD', '1.13', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 3), 'USD', '1.14', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 5), 'CAD', '0.86956', 'USD'),
        price(BeanDate(year: 2013, month: 6, day: 6), 'CAD', '0.86207', 'USD'),
      ]);

      final CurrencyPair pair = CurrencyPair(
        base: Currency(name: 'USD'),
        quote: Currency(name: 'CAD'),
      );
      expect(map.rates.keys.toSet(), <CurrencyPair>{
        pair,
        CurrencyPair(
          base: Currency(name: 'CAD'),
          quote: Currency(name: 'USD'),
        ),
      });
      final List<PricePoint> values = map.allPrices(pair);
      expect(values.map((PricePoint p) => (p.date, p.rate.round(scale: 2))).toList(), <(BeanDate, Decimal)>[
        (BeanDate(year: 2013, month: 6, day: 1), Decimal.parse('1.10')),
        (BeanDate(year: 2013, month: 6, day: 2), Decimal.parse('1.13')),
        (BeanDate(year: 2013, month: 6, day: 3), Decimal.parse('1.14')),
        (BeanDate(year: 2013, month: 6, day: 5), Decimal.parse('1.15')),
        (BeanDate(year: 2013, month: 6, day: 6), Decimal.parse('1.16')),
      ]);
    });

    test('priceAt returns as-of rate', () {
      final PriceMap map = PriceMap.build(<Directive>[
        price(BeanDate(year: 2013, month: 6, day: 1), 'USD', '1.00', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 10), 'USD', '1.50', 'CAD'),
        price(BeanDate(year: 2013, month: 7, day: 1), 'USD', '2.00', 'CAD'),
      ]);
      final CurrencyPair pair = CurrencyPair(
        base: Currency(name: 'USD'),
        quote: Currency(name: 'CAD'),
      );
      expect(map.priceAt(pair, BeanDate(year: 2013, month: 5, day: 15)), isNull);
      expect(
        map.priceAt(pair, BeanDate(year: 2013, month: 6, day: 5)),
        PriceQuote(date: BeanDate(year: 2013, month: 6, day: 1), rate: Decimal.parse('1.00')),
      );
      expect(
        map.priceAt(pair, BeanDate(year: 2013, month: 6, day: 20)),
        PriceQuote(date: BeanDate(year: 2013, month: 6, day: 10), rate: Decimal.parse('1.50')),
      );
      expect(map.latestPrice(pair)?.rate, Decimal.parse('2.00'));
    });

    test('project inserts combined quote rates without mutating the original', () {
      final PriceMap map = PriceMap.build(<Directive>[
        price(BeanDate(year: 2013, month: 6, day: 1), 'USD', '1.12', 'CAD'),
        price(BeanDate(year: 2013, month: 6, day: 15), 'HOOL', '1000.00', 'USD'),
        price(BeanDate(year: 2013, month: 6, day: 15), 'MFFT', '200.00', 'USD'),
        price(BeanDate(year: 2013, month: 7, day: 1), 'USD', '1.13', 'CAD'),
        price(BeanDate(year: 2013, month: 7, day: 15), 'HOOL', '1010.00', 'USD'),
      ]);
      final PriceMap projected = map.project(Currency(name: 'USD'), Currency(name: 'CAD'));
      expect(
        map.rates.containsKey(
          CurrencyPair(
            base: Currency(name: 'HOOL'),
            quote: Currency(name: 'CAD'),
          ),
        ),
        isFalse,
      );
      expect(
        projected.allPrices(
          CurrencyPair(
            base: Currency(name: 'HOOL'),
            quote: Currency(name: 'CAD'),
          ),
        ),
        <PricePoint>[
          PricePoint(date: BeanDate(year: 2013, month: 6, day: 15), rate: Decimal.parse('1120.00')),
          PricePoint(date: BeanDate(year: 2013, month: 7, day: 15), rate: Decimal.parse('1141.30')),
        ],
      );
      final PriceMap constrained = map.project(
        Currency(name: 'USD'),
        Currency(name: 'CAD'),
        baseCurrencies: <Currency>{Currency(name: 'MFFT')},
      );
      expect(
        constrained.rates.containsKey(
          CurrencyPair(
            base: Currency(name: 'HOOL'),
            quote: Currency(name: 'CAD'),
          ),
        ),
        isFalse,
      );
    });

    test('build inserts rates from posting prices and augmenting costs', () {
      final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
      final BeanDate date = BeanDate(year: 2025, month: 3, day: 1);
      final Account shares = account('Assets:Shares:IBM', AccountType.assets);
      final Account cash = account('Assets:Cash', AccountType.assets);
      final PriceMap map = PriceMap.build(<Directive>[
        Directive(
          origin: origin,
          date: date,
          body: DirectiveBody.transaction(
            Transaction(
              origin: origin,
              flag: const Flag.special(SpecialFlag.asterisk),
              narration: 'buy with cost',
              postings: <Posting>[
                Posting(origin: origin, account: shares, units: amount('5', 'IBM'), cost: cost('300.00', 'NZD', date)),
                Posting(origin: origin, account: cash, units: amount('-1500.00', 'NZD')),
              ],
            ),
          ),
        ),
        Directive(
          origin: origin,
          date: BeanDate(year: 2025, month: 3, day: 2),
          body: DirectiveBody.transaction(
            Transaction(
              origin: origin,
              flag: const Flag.special(SpecialFlag.asterisk),
              narration: 'fx with price',
              postings: <Posting>[
                Posting(origin: origin, account: cash, units: amount('-100', 'GBP'), price: amount('2.00', 'NZD')),
                Posting(origin: origin, account: cash, units: amount('200', 'NZD')),
              ],
            ),
          ),
        ),
        Directive(
          origin: origin,
          date: BeanDate(year: 2025, month: 3, day: 3),
          body: DirectiveBody.transaction(
            Transaction(
              origin: origin,
              flag: const Flag.special(SpecialFlag.asterisk),
              narration: 'sell reducing lot does not insert cost price',
              postings: <Posting>[
                Posting(origin: origin, account: shares, units: amount('-2', 'IBM'), cost: cost('300.00', 'NZD', date)),
                Posting(origin: origin, account: cash, units: amount('600', 'NZD')),
              ],
            ),
          ),
        ),
      ]);

      expect(
        map
            .priceAt(
              CurrencyPair(
                base: Currency(name: 'IBM'),
                quote: Currency(name: 'NZD'),
              ),
              date,
            )
            ?.rate,
        Decimal.parse('300.00'),
      );
      expect(
        map
            .priceAt(
              CurrencyPair(
                base: Currency(name: 'GBP'),
                quote: Currency(name: 'NZD'),
              ),
              BeanDate(year: 2025, month: 3, day: 2),
            )
            ?.rate,
        Decimal.parse('2.00'),
      );
      expect(
        map.allPrices(
          CurrencyPair(
            base: Currency(name: 'IBM'),
            quote: Currency(name: 'NZD'),
          ),
        ),
        <PricePoint>[PricePoint(date: date, rate: Decimal.parse('300.00'))],
      );
    });
  });
}
