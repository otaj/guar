// Port of beancount.plugins.noduplicates tests.

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('flags duplicate transactions', () {
    expect(
      messages(
        'plugin "beancount.plugins.noduplicates"\n'
        '2014-01-01 open Assets:Investments:Stock\n'
        '2014-01-01 open Assets:Investments:Cash\n'
        '2014-06-24 * "Go negative from zero"\n'
        '  Assets:Investments:Stock    1 HOOL {500 USD}\n'
        '  Assets:Investments:Cash  -500 USD\n'
        '2014-06-24 * "Go negative from zero"\n'
        '  Assets:Investments:Stock    1 HOOL {500 USD}\n'
        '  Assets:Investments:Cash  -500 USD\n',
      ),
      contains(startsWith('Duplicate entry:')),
    );
  });

  test('flags duplicate notes', () {
    expect(
      messages(
        'plugin "beancount.plugins.noduplicates"\n'
        '2000-01-01 open Assets:Checking\n'
        '2001-01-01 note Assets:Checking "Something about something"\n'
        '2001-01-01 note Assets:Checking "Something about something"\n',
      ),
      contains(startsWith('Duplicate entry:')),
    );
  });

  test('allows exact duplicate price directives', () {
    expect(
      messages(
        'plugin "beancount.plugins.noduplicates"\n'
        '2000-01-01 price HOOL 500 USD\n'
        '2000-01-01 price HOOL 500 USD\n',
      ),
      isEmpty,
    );
  });
}
