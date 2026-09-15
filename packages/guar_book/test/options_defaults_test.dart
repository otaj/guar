// Defaults for unset LedgerOptions before booking.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:guar_parser/guar_parser.dart' as p;
import 'package:test/test.dart';

void main() {
  test('defaultOptions fills beancount OPTIONS_DEFAULTS', () {
    final options = defaultOptions(const p.LedgerOptions());
    expect(options.title, 'Beancount');
    expect(options.accountPrefixes.assets, 'Assets');
    expect(options.accountPrefixes.liabilities, 'Liabilities');
    expect(options.accountPrefixes.equity, 'Equity');
    expect(options.accountPrefixes.income, 'Income');
    expect(options.accountPrefixes.expenses, 'Expenses');
    expect(options.bookingMethod, BookingMethod.strict);
    expect(options.pluginProcessingMode, PluginProcessingMode.defaultMode);
    expect(options.toleranceMultiplier, Decimal.parse('0.5'));
    expect(options.conversionCurrency, const Currency(name: 'NOTHING'));
    expect(options.accountPreviousBalances?.name, 'Equity:Opening-Balances');
    expect(options.accountPreviousEarnings?.name, 'Equity:Earnings:Previous');
    expect(options.accountCurrentEarnings?.name, 'Equity:Earnings:Current');
    expect(options.accountUnrealizedGains?.name, 'Equity:Earnings:Unrealized');
    expect(options.accountRounding, isNull);
    expect(options.renderCommas, isFalse);
    expect(options.longStringMaxlines, 64);
  });

  test('defaultOptions keeps explicit file options', () {
    final options = defaultOptions(
      const p.LedgerOptions(
        title: 'My Books',
        accountPrefixes: p.AccountPrefixes(assets: 'Actifs', equity: 'Capitaux'),
        bookingMethod: p.BookingMethod.fifo,
      ),
    );
    expect(options.title, 'My Books');
    expect(options.accountPrefixes.assets, 'Actifs');
    expect(options.accountPrefixes.equity, 'Capitaux');
    expect(options.accountPrefixes.liabilities, 'Liabilities');
    expect(options.bookingMethod, BookingMethod.fifo);
    expect(options.accountPreviousBalances?.name, 'Capitaux:Opening-Balances');
  });

  test('Book.process applies defaults on an empty successful ledger', () {
    final ledger = const Book().process(const p.ParsedLedger.directives(directives: []));
    expect(ledger, isA<LedgerDirectives>());
    final options = (ledger as LedgerDirectives).options;
    expect(options.bookingMethod, BookingMethod.strict);
    expect(options.title, 'Beancount');
  });
}
