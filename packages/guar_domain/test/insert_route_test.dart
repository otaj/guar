// Insert-entry / default-file / root routing for in-memory directive inserts.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  const String root = 'ledger.beancount';
  const String expenses = 'expenses.beancount';
  const String other = 'other.beancount';
  const ProcessingInfo info = ProcessingInfo(filename: root, include: <String>[expenses, other]);
  final BeanDate date = BeanDate(year: 2024, month: 6, day: 1);

  Origin source(String filename, int line) =>
      Origin.source(BeanLocation(filename: filename, linenoBegin: line, linenoEnd: line));

  Directive custom({
    required String filename,
    required int line,
    required BeanDate at,
    required String option,
    String? value,
  }) => Directive(
    origin: source(filename, line),
    date: at,
    body: DirectiveBody.custom(
      type: 'fava-option',
      values: <CustomValue>[CustomValue.text(option), if (value != null) CustomValue.text(value)],
    ),
  );

  Directive open(String account, {String filename = root, int line = 1, BeanDate? at}) => Directive(
    origin: source(filename, line),
    date: at ?? BeanDate(year: 2014, month: 1, day: 1),
    body: DirectiveBody.open(
      account: Account(name: account, type: AccountType.assets),
    ),
  );

  test('unrouted entries go to the root', () {
    final BeanLocation location = insertLocation(
      date: date,
      body: DirectiveBody.open(
        account: Account(name: 'Assets:Cash', type: AccountType.assets),
      ),
      existing: <Directive>[open('Assets:Cash')],
      info: info,
    );
    expect(location.filename, root);
  });

  test('insert-entry is prefix-anchored and uses the rule file', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 3,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
    ];
    final BeanLocation location = insertLocation(
      date: date,
      body: DirectiveBody.open(
        account: Account(name: 'Expenses:Food', type: AccountType.expenses),
      ),
      existing: rules,
      info: info,
    );
    expect(location.filename, expenses);
    expect(location.linenoBegin, 3);
    final BeanLocation missed = insertLocation(
      date: date,
      body: DirectiveBody.open(
        account: Account(name: 'Assets:Food', type: AccountType.assets),
      ),
      existing: rules,
      info: info,
    );
    expect(missed.filename, root);
  });

  test('transactions match posting accounts in reverse order', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
      custom(
        filename: other,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Assets',
      ),
    ];
    DirectiveBody txn(List<String> accounts) => DirectiveBody.transaction(
      Transaction(
        origin: source(root, 1),
        flag: const Flag.special(SpecialFlag.asterisk),
        postings: <Posting>[
          for (final String name in accounts)
            Posting(
              origin: source(root, 2),
              account: Account(
                name: name,
                type: name.startsWith('Expenses') ? AccountType.expenses : AccountType.assets,
              ),
              units: Amount(
                number: Decimal.one,
                currency: Currency(name: 'USD'),
              ),
            ),
        ],
      ),
    );

    expect(
      insertLocation(
        date: date,
        body: txn(<String>['Expenses:Food', 'Assets:Cash']),
        existing: rules,
        info: info,
      ).filename,
      other,
    );
    expect(
      insertLocation(
        date: date,
        body: txn(<String>['Assets:Cash', 'Expenses:Food']),
        existing: rules,
        info: info,
      ).filename,
      expenses,
    );
  });

  test('pad matches padded account before source account', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Assets:Cash',
      ),
      custom(
        filename: other,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Equity',
      ),
    ];
    final BeanLocation location = insertLocation(
      date: date,
      body: DirectiveBody.pad(
        account: Account(name: 'Assets:Cash', type: AccountType.assets),
        sourceAccount: Account(name: 'Equity:Opening', type: AccountType.equity),
      ),
      existing: rules,
      info: info,
    );
    expect(location.filename, expenses);
  });

  test('commodity and price never match insert-entry', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Assets',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.commodity(currency: Currency(name: 'USD')),
        existing: rules,
        info: info,
      ).filename,
      root,
    );
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.price(
          currency: Currency(name: 'EUR'),
          amount: Amount(
            number: Decimal.one,
            currency: Currency(name: 'USD'),
          ),
        ),
        existing: rules,
        info: info,
      ).filename,
      root,
    );
  });

  test('a rule applies only when its date is strictly before the entry', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2024, month: 6, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.open(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
        ),
        existing: rules,
        info: info,
      ).filename,
      root,
    );
  });

  test('latest applicable insert-entry for the winning account wins', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: other,
        line: 1,
        at: BeanDate(year: 2010, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.open(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
        ),
        existing: rules,
        info: info,
      ).filename,
      expenses,
    );
    expect(
      insertLocation(
        date: BeanDate(year: 2015, month: 1, day: 1),
        body: DirectiveBody.open(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
        ),
        existing: rules,
        info: info,
      ).filename,
      other,
    );
  });

  test('account priority beats a later-dated rule on a lower-priority account', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 1,
        at: BeanDate(year: 2010, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Assets:Cash',
      ),
      custom(
        filename: other,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Equity',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.pad(
          account: Account(name: 'Assets:Cash', type: AccountType.assets),
          sourceAccount: Account(name: 'Equity:Opening', type: AccountType.equity),
        ),
        existing: rules,
        info: info,
      ).filename,
      expenses,
    );
  });

  test('unmatched entries use default-file when that file is already in the tree', () {
    final List<Directive> existing = <Directive>[
      custom(
        filename: root,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'default-file',
        value: 'other.beancount',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.commodity(currency: Currency(name: 'USD')),
        existing: existing,
        info: info,
      ).filename,
      other,
    );
  });

  test('default-file with no path uses the file that contains the directive', () {
    final List<Directive> existing = <Directive>[
      custom(filename: other, line: 1, at: BeanDate(year: 2020, month: 1, day: 1), option: 'default-file'),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.commodity(currency: Currency(name: 'USD')),
        existing: existing,
        info: info,
      ).filename,
      other,
    );
  });

  test('default-file outside the include tree is ignored', () {
    final List<Directive> existing = <Directive>[
      custom(
        filename: root,
        line: 1,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'default-file',
        value: 'missing.beancount',
      ),
    ];
    expect(
      insertLocation(
        date: date,
        body: DirectiveBody.commodity(currency: Currency(name: 'USD')),
        existing: existing,
        info: info,
      ).filename,
      root,
    );
  });

  test('open, close, balance, note, and document route by their account', () {
    final List<Directive> rules = <Directive>[
      custom(
        filename: expenses,
        line: 4,
        at: BeanDate(year: 2020, month: 1, day: 1),
        option: 'insert-entry',
        value: 'Expenses',
      ),
    ];
    BeanLocation route(DirectiveBody body) => insertLocation(date: date, body: body, existing: rules, info: info);
    expect(
      route(
        DirectiveBody.open(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
        ),
      ).filename,
      expenses,
    );
    expect(
      route(
        DirectiveBody.close(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
        ),
      ).filename,
      expenses,
    );
    expect(
      route(
        DirectiveBody.balance(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
          amount: Amount(
            number: Decimal.zero,
            currency: Currency(name: 'USD'),
          ),
        ),
      ).filename,
      expenses,
    );
    expect(
      route(
        DirectiveBody.note(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
          comment: 'ok',
        ),
      ).filename,
      expenses,
    );
    expect(
      route(
        DirectiveBody.document(
          account: Account(name: 'Expenses:Food', type: AccountType.expenses),
          filename: 'receipt.pdf',
        ),
      ).filename,
      expenses,
    );
  });

  test('option and plugin inserts are the root file, never an included file', () {
    final BeanLocation location = optionPluginLocation(info);
    expect(location.filename, root);
    expect(location.filename, isNot(expenses));
    expect(location.filename, isNot(other));
    expect(info.include, containsAll(<dynamic>[expenses, other]));
    expect(optionPluginLocation(const ProcessingInfo()).filename, '');
  });
}
