// Date-range clamp of a booked ledger (beancount.ops.summarize.clamp_opt).

import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:guar_query/guar_query.dart';
import 'package:test/test.dart';

const String _source = '''
2024-01-01 open Assets:Bank USD
2024-01-01 open Expenses:Food USD
2024-01-01 open Income:Salary USD

2024-01-15 * "Salary"
  Assets:Bank        1000.00 USD
  Income:Salary     -1000.00 USD

2024-02-15 * "Groceries"
  Expenses:Food       50.00 USD
  Assets:Bank        -50.00 USD

2024-03-15 * "More groceries"
  Expenses:Food       30.00 USD
  Assets:Bank        -30.00 USD
''';

Ledger _book(String source) {
  final p.ParsedLedger parsed = const p.BeancountParser().parse(source, filename: 'test.beancount');
  final Ledger booked = Book().process(parsed);
  expect(booked, isA<LedgerDirectives>(), reason: booked is LedgerErrors ? booked.errors.toString() : null);
  return booked;
}

List<Directive> _txns(Ledger ledger) {
  expect(ledger, isA<LedgerDirectives>());
  return <Directive>[
    for (final Directive directive in (ledger as LedgerDirectives).directives)
      if (directive.body is TransactionBody) directive,
  ];
}

String _narration(Directive directive) => (directive.body as TransactionBody).value.narration;

void main() {
  late Ledger ledger;

  setUpAll(() {
    ledger = _book(_source);
  });

  test('entry on start date is included', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 2, day: 15),
      BeanDate(year: 2024, month: 3, day: 1),
    );
    final List<Directive> groceries = <Directive>[
      for (final Directive txn in _txns(clamped))
        if (txn.date == BeanDate(year: 2024, month: 2, day: 15) && _narration(txn) == 'Groceries') txn,
    ];
    expect(groceries, hasLength(1));
  });

  test('entry on end date is excluded', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 2, day: 1),
      BeanDate(year: 2024, month: 3, day: 15),
    );
    expect(_txns(clamped).where((Directive txn) => txn.date.toString().compareTo('2024-03-15') >= 0), isEmpty);
  });

  test('empty window still has opening-balance entries', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 4, day: 1),
      BeanDate(year: 2024, month: 5, day: 1),
    );
    final List<Directive> txns = _txns(clamped);
    expect(txns, isNotEmpty);
    for (final Directive txn in txns) {
      final String narration = _narration(txn);
      expect(narration.contains('Summarization') || narration.contains('Opening'), isTrue);
    }
  });

  test('opening entries use summarization narration and equity', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 2, day: 1),
      BeanDate(year: 2024, month: 3, day: 1),
    );
    final List<Directive> opening = <Directive>[
      for (final Directive txn in _txns(clamped))
        if (_narration(txn).contains('Summarization')) txn,
    ];
    expect(opening, isNotEmpty);
    for (final Directive txn in opening) {
      expect(_narration(txn), contains('Opening balance'));
      final List<String> accounts = <String>[
        for (final Posting posting in (txn.body as TransactionBody).value.postings) posting.account.name,
      ];
      expect(accounts.any((String name) => name.startsWith('Equity:')), isTrue);
    }
  });

  test('regular transactions before start date are dropped', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 2, day: 1),
      BeanDate(year: 2024, month: 3, day: 1),
    );
    expect(
      _txns(
        clamped,
      ).where(
        (Directive txn) =>
            txn.date.toString().compareTo('2024-01-31') < 0 && !_narration(txn).contains('Summarization'),
      ),
      isEmpty,
    );
  });

  test('regular transactions are strictly before end date', () {
    final Ledger clamped = clamp(
      ledger,
      BeanDate(year: 2024, month: 2, day: 1),
      BeanDate(year: 2024, month: 3, day: 1),
    );
    final List<Directive> regular = <Directive>[
      for (final Directive txn in _txns(clamped))
        if (!_narration(txn).contains('Summarization')) txn,
    ];
    expect(regular.every((Directive txn) => txn.date.toString().compareTo('2024-03-01') < 0), isTrue);
  });

  test('errors ledger is unchanged', () {
    final Ledger errors = Ledger.errors(
      errors: <ProcessingError>[ProcessingError(message: 'boom', location: BeanLocation(linenoBegin: 1, linenoEnd: 1))],
      options: LedgerOptions(),
    );
    expect(clamp(errors, BeanDate(year: 2024, month: 1, day: 1), BeanDate(year: 2024, month: 2, day: 1)), same(errors));
  });

  test('clamp keeps parse warnings', () {
    final Ledger warned = _book('option "insert_pythonpath" "TRUE"\n$_source');
    expect((warned as LedgerDirectives).warnings, isNotEmpty);
    final Ledger clamped = clamp(
      warned,
      BeanDate(year: 2024, month: 2, day: 1),
      BeanDate(year: 2024, month: 3, day: 1),
    );
    expect((clamped as LedgerDirectives).warnings, warned.warnings);
  });
}
