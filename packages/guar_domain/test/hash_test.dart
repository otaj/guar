// Stored directive hashes ignore origin and meta.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  final Origin source = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
  final Origin elsewhere = Origin.source(BeanLocation(linenoBegin: 9, linenoEnd: 9));
  final BeanDate date = BeanDate(year: 2024, month: 1, day: 1);
  final Account checking = account('Assets:Checking', AccountType.assets);

  Directive open({Origin? origin, Meta meta = const Meta(), String name = 'Assets:Checking'}) => Directive(
    origin: origin ?? source,
    date: date,
    meta: meta,
    body: DirectiveBody.open(account: account(name, AccountType.assets)),
  );

  test('hash is a 32-character lowercase hex digest', () {
    expect(open().hash, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('same date and body yield the same hash across origins and meta', () {
    final Directive left = open();
    final Directive right = open(
      origin: elsewhere,
      meta: const Meta(
        entries: <MetaEntry>[MetaEntry(key: 'filename', value: MetaValue.text('other.beancount'))],
      ),
    );
    expect(left.hash, right.hash);
    expect(left, isNot(right));
  });

  test('different accounts hash differently', () {
    expect(open().hash, isNot(open(name: 'Assets:Savings').hash));
  });

  test('copyWith rematerializes after a body change and keeps hash when only meta changes', () {
    final Directive original = open();
    final Directive renamed = original.copyWith(
      body: DirectiveBody.open(account: account('Assets:Savings', AccountType.assets)),
    );
    expect(renamed.hash, isNot(original.hash));
    expect(renamed.hash, open(name: 'Assets:Savings').hash);

    final Directive annotated = original.copyWith(
      meta: const Meta(
        entries: <MetaEntry>[MetaEntry(key: 'note', value: MetaValue.text('x'))],
      ),
    );
    expect(annotated.hash, original.hash);
  });

  test('transaction postings participate in the hash', () {
    Directive txn(List<Posting> postings) => Directive(
      origin: source,
      date: date,
      body: DirectiveBody.transaction(
        Transaction(
          origin: source,
          flag: const Flag.special(SpecialFlag.asterisk),
          narration: 'balance seed',
          postings: postings,
        ),
      ),
    );

    final Directive seeded = txn(<Posting>[
      Posting(origin: source, account: checking, units: amount('100.00', 'USD')),
      Posting(origin: source, account: account('Equity:Opening', AccountType.equity), units: amount('-100.00', 'USD')),
    ]);
    final Directive different = txn(<Posting>[
      Posting(origin: source, account: checking, units: amount('50.00', 'USD')),
      Posting(origin: source, account: account('Equity:Opening', AccountType.equity), units: amount('-50.00', 'USD')),
    ]);
    expect(seeded.hash, isNot(different.hash));
  });
}
