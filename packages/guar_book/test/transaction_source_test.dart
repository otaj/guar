// Rendered transaction directives parse back into the same parsed transaction.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

p.ParsedTransaction _parseOne(String source) {
  final p.ParsedLedger parsed = const p.BeancountParser().parse(source, filename: 't.beancount', followIncludes: false);
  final List<p.ParsedDirective> directives = switch (parsed) {
    p.ParsedLedgerDirectives(:final List<p.ParsedDirective> directives) => directives,
    p.ParsedLedgerErrors(:final List<p.ParseError> errors) => fail('parse errors: $errors'),
  };
  final List<p.ParsedTransaction> transactions = <p.ParsedTransaction>[
    for (final p.ParsedDirective directive in directives)
      if (directive.body is p.TransactionBody) (directive.body as p.TransactionBody).value,
  ];
  return transactions.single;
}

p.BeanDate _d(int year, int month, int day) => p.BeanDate(year: year, month: month, day: day);

void main() {
  final p.BeanDate date = _d(2026, 11, 9);
  final p.BeanLocation at = p.BeanLocation(filename: 't', linenoBegin: 1, linenoEnd: 1);
  final p.Account cash = p.Account(name: 'Assets:Cash');
  final p.Account food = p.Account(name: 'Expenses:Food');
  final p.Currency usd = p.Currency(name: 'USD');
  final p.Currency eur = p.Currency(name: 'EUR');
  p.BeanNumber n(String verbatim) => p.BeanNumber(verbatim: verbatim, resolved: Decimal.parse(verbatim));

  p.ParsedDirective directive(
    p.ParsedTransaction transaction, {
    p.BeanDate? day,
    p.Meta meta = const p.Meta(),
  }) => p.ParsedDirective(location: at, date: day ?? date, body: p.TransactionBody(transaction), meta: meta);

  test('renders payee, narration, and two amounts', () {
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.asterisk),
          payee: 'Grocer',
          narration: 'Lunch',
          postings: <p.ParsedPosting>[
            p.ParsedPosting(
              location: at,
              account: food,
              units: p.IncompleteAmount(number: n('12.30'), currency: usd),
            ),
            p.ParsedPosting(
              location: at,
              account: cash,
              units: p.IncompleteAmount(number: n('-12.30'), currency: usd),
            ),
          ],
        ),
      ),
    );
    expect(
      out,
      '2026-11-09 * "Grocer" "Lunch"\n'
      '  Expenses:Food  12.30 USD\n'
      '  Assets:Cash  -12.30 USD\n',
    );
    expect(_parseOne(out).postings[0].units?.number?.verbatim, '12.30');
  });

  test('renders narration without payee', () {
    final String out = writeTransaction(
      directive(
        const p.ParsedTransaction(
          flag: p.Flag.special(p.SpecialFlag.asterisk),
          narration: 'Withdrawal',
        ),
      ),
    );
    expect(out, '2026-11-09 * "Withdrawal"\n');
  });

  test('renders flags, tags, links, and posting flags', () {
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.exclamation),
          payee: 'P',
          narration: 'N',
          tags: <p.Tag>[p.Tag(name: 'trip')],
          links: <p.Link>[p.Link(name: 'abc')],
          postings: <p.ParsedPosting>[
            p.ParsedPosting(location: at, account: cash, flag: const p.Flag.special(p.SpecialFlag.question)),
          ],
        ),
      ),
    );
    expect(out, '2026-11-09 ! "P" "N" #trip ^abc\n  ? Assets:Cash\n');
  });

  test('renders elided and currency-only legs', () {
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.asterisk),
          narration: 'X',
          postings: <p.ParsedPosting>[
            p.ParsedPosting(
              location: at,
              account: food,
              units: p.IncompleteAmount(currency: usd),
            ),
            p.ParsedPosting(location: at, account: cash),
          ],
        ),
      ),
    );
    expect(
      out,
      '2026-11-09 * "X"\n'
      '  Expenses:Food  USD\n'
      '  Assets:Cash\n',
    );
  });

  test('renders per-unit, total, and compound costs', () {
    p.ParsedCost cost({p.BeanNumber? per, p.BeanNumber? total, p.Currency? currency, p.BeanDate? at, String? label}) =>
        p.ParsedCost(numberPer: per, numberTotal: total, currency: currency, date: at, label: label);
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.asterisk),
          narration: 'C',
          postings: <p.ParsedPosting>[
            p.ParsedPosting(
              location: at,
              account: food,
              units: p.IncompleteAmount(number: n('2'), currency: usd),
              cost: cost(per: n('1.10'), currency: eur),
            ),
            p.ParsedPosting(
              location: at,
              account: food,
              cost: cost(total: n('22'), currency: eur),
            ),
            p.ParsedPosting(
              location: at,
              account: food,
              cost: cost(per: n('1'), total: n('3'), currency: eur, at: date, label: 'L'),
            ),
            p.ParsedPosting(
              location: at,
              account: food,
              units: p.IncompleteAmount(currency: usd),
              cost: p.ParsedCost(merge: true, currency: eur),
            ),
          ],
        ),
      ),
    );
    expect(
      out.split('\n').skip(1).take(4).join('\n'),
      <String>[
        '  Expenses:Food  2 USD {1.10 EUR}',
        '  Expenses:Food  {{22 EUR}}',
        '  Expenses:Food  {1 # 3 EUR, 2026-11-09, "L"}',
        '  Expenses:Food  USD {EUR, *}',
      ].join('\n'),
    );
  });

  test('renders per-unit and total prices', () {
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.asterisk),
          narration: 'X',
          postings: <p.ParsedPosting>[
            p.ParsedPosting(
              location: at,
              account: food,
              units: p.IncompleteAmount(number: n('2'), currency: usd),
              price: p.ParsedPrice(number: n('1.10'), currency: eur),
            ),
            p.ParsedPosting(
              location: at,
              account: food,
              price: p.ParsedPrice(number: n('2.20'), currency: eur, isTotal: true),
            ),
          ],
        ),
      ),
    );
    expect(
      out.split('\n').skip(1).take(2).join('\n'),
      '  Expenses:Food  2 USD @ 1.10 EUR\n  Expenses:Food  @@ 2.20 EUR',
    );
  });

  test('renders transaction and posting metadata', () {
    final p.Meta txnMeta = p.Meta(
      entries: <p.MetaEntry>[
        const p.MetaEntry(key: 'reason', value: p.MetaValue.text('why not')),
        p.MetaEntry(key: 'count', value: p.MetaValue.number(n('3'))),
        p.MetaEntry(key: 'when', value: p.MetaValue.date(date)),
        p.MetaEntry(key: 'to', value: p.MetaValue.account(cash)),
        p.MetaEntry(key: 'cur', value: p.MetaValue.currency(usd)),
        p.MetaEntry(
          key: 'mark',
          value: p.MetaValue.tag(p.Tag(name: 't')),
        ),
        const p.MetaEntry(key: 'on', value: p.MetaValue.boolean(true)),
        p.MetaEntry(
          key: 'amt',
          value: p.MetaValue.amount(p.Amount(number: n('1.50'), currency: usd)),
        ),
        const p.MetaEntry(key: 'empty'),
      ],
    );
    final String out = writeTransaction(
      directive(
        p.ParsedTransaction(
          flag: const p.Flag.special(p.SpecialFlag.asterisk),
          narration: 'X',
          postings: <p.ParsedPosting>[
            p.ParsedPosting(
              location: at,
              account: food,
              meta: const p.Meta(
                entries: <p.MetaEntry>[p.MetaEntry(key: 'note', value: p.MetaValue.text('hi'))],
              ),
            ),
            p.ParsedPosting(location: at, account: cash),
          ],
        ),
        meta: txnMeta,
      ),
    );
    expect(out.split('\n'), <String>[
      '2026-11-09 * "X"',
      '  reason: "why not"',
      '  count: 3',
      '  when: 2026-11-09',
      '  to: Assets:Cash',
      '  cur: USD',
      '  mark: #t',
      '  on: TRUE',
      '  amt: 1.50 USD',
      '  empty:',
      '  Expenses:Food',
      '  note: "hi"',
      '  Assets:Cash',
      '',
    ]);
  });

  test('a double quote in text fails instead of writing invalid syntax', () {
    expect(
      () => writeTransaction(
        directive(
          const p.ParsedTransaction(
            flag: p.Flag.special(p.SpecialFlag.asterisk),
            narration: 'He said "hi"',
          ),
        ),
      ),
      throwsFormatException,
    );
  });
}
