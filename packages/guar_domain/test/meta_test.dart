// Lookup of metadata values by key on booked Meta.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  test('lookup returns the first matching value', () {
    final Meta meta = Meta(
      entries: <MetaEntry>[
        const MetaEntry(key: 'note', value: MetaValue.text('hello')),
        MetaEntry(
          key: 'account',
          value: MetaValue.account(Account(name: 'Assets:Cash', type: AccountType.assets)),
        ),
      ],
    );
    expect(meta.lookup('note'), const MetaValue.text('hello'));
    expect(meta.lookup('missing'), isNull);
  });

  test('lookup returns a null value when the key is present without a value', () {
    const Meta meta = Meta(entries: <MetaEntry>[MetaEntry(key: 'empty')]);
    expect(meta.lookup('empty'), isNull);
  });
}
