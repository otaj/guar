// Ledger XOR between booked directives and processing errors.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

import 'helpers/amounts.dart';

void main() {
  test('successful ledger holds directives only', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Ledger ledger = Ledger.directives(
      directives: <Directive>[
        Directive(
          origin: origin,
          date: BeanDate(year: 2025, month: 1, day: 1),
          body: DirectiveBody.open(account: account('Assets:Cash', AccountType.assets)),
        ),
      ],
      options: LedgerOptions(),
    );
    expect(ledger, isA<LedgerDirectives>());
    expect((ledger as LedgerDirectives).directives, hasLength(1));
  });

  test('failed ledger holds errors only', () {
    final Ledger ledger = Ledger.errors(
      errors: <ProcessingError>[
        ProcessingError(
          message: 'Invalid reference to unknown account',
          location: BeanLocation(linenoBegin: 10, linenoEnd: 10),
        ),
      ],
      options: LedgerOptions(),
    );
    expect(ledger, isA<LedgerErrors>());
    expect((ledger as LedgerErrors).errors.single.message, contains('unknown account'));
  });

  test('recover-shaped ledger holds directives and errors together', () {
    final Origin origin = Origin.source(BeanLocation(linenoBegin: 1, linenoEnd: 1));
    final Ledger ledger = Ledger.directives(
      directives: <Directive>[
        Directive(
          origin: origin,
          date: BeanDate(year: 2025, month: 1, day: 1),
          body: DirectiveBody.open(account: account('Assets:Cash', AccountType.assets)),
        ),
      ],
      errors: <ProcessingError>[
        ProcessingError(message: 'Balance failed', location: BeanLocation(linenoBegin: 4, linenoEnd: 4)),
      ],
      options: LedgerOptions(),
    );
    expect(ledger, isA<LedgerDirectives>());
    final LedgerDirectives recovered = ledger as LedgerDirectives;
    expect(recovered.directives, hasLength(1));
    expect(recovered.errors, hasLength(1));
    expect(recovered.errors.single.message, 'Balance failed');
  });
}
