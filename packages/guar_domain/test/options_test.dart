// Booked LedgerOptions apply Beancount OPTIONS_DEFAULTS at construction.

import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  test('LedgerOptions fills beancount defaults', () {
    final options = LedgerOptions();
    expect(options.title, 'Beancount');
    expect(options.accountPrefixes.assets, 'Assets');
    expect(options.accountPrefixes.liabilities, 'Liabilities');
    expect(options.accountPrefixes.equity, 'Equity');
    expect(options.accountPrefixes.income, 'Income');
    expect(options.accountPrefixes.expenses, 'Expenses');
    expect(options.accountPreviousBalances.name, 'Equity:Opening-Balances');
    expect(options.accountPreviousEarnings.name, 'Equity:Earnings:Previous');
    expect(options.accountPreviousConversions.name, 'Equity:Conversions:Previous');
    expect(options.accountCurrentEarnings.name, 'Equity:Earnings:Current');
    expect(options.accountCurrentConversions.name, 'Equity:Conversions:Current');
    expect(options.accountUnrealizedGains.name, 'Income:Earnings:Unrealized');
    expect(options.accountRounding, isNull);
    expect(options.conversionCurrency.name, 'NOTHING');
    expect(options.inferredToleranceMultiplier.toString(), '0.5');
    expect(options.toleranceMultiplier.toString(), '0.5');
    expect(options.inferToleranceFromCost, isFalse);
    expect(options.renderCommas, isFalse);
    expect(options.pluginProcessingMode, PluginProcessingMode.defaultMode);
    expect(options.longStringMaxlines, 64);
    expect(options.bookingMethod, BookingMethod.strict);
    expect(options.usePreciseInterpolation, isFalse);
    expect(options.insertPythonpath, isFalse);
    expect(options.allowPipeSeparator, isFalse);
    expect(options.allowDeprecatedNoneForTagsAndLinks, isFalse);
  });
}
