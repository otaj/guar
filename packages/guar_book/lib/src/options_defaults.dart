// Fill unset parse-time LedgerOptions from beancount OPTIONS_DEFAULTS.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

d.LedgerOptions defaultOptions(p.LedgerOptions options) {
  final prefixes = d.AccountPrefixes(
    assets: options.accountPrefixes.assets ?? 'Assets',
    liabilities: options.accountPrefixes.liabilities ?? 'Liabilities',
    equity: options.accountPrefixes.equity ?? 'Equity',
    income: options.accountPrefixes.income ?? 'Income',
    expenses: options.accountPrefixes.expenses ?? 'Expenses',
  );
  final equity = prefixes.equity!;

  return d.LedgerOptions(
    accountPrefixes: prefixes,
    title: options.title ?? 'Beancount',
    accountPreviousBalances: _resolvedOptionAccount(
      options.accountPreviousBalances?.name,
      '$equity:Opening-Balances',
      prefixes,
    ),
    accountPreviousEarnings: _resolvedOptionAccount(
      options.accountPreviousEarnings?.name,
      '$equity:Earnings:Previous',
      prefixes,
    ),
    accountPreviousConversions: _resolvedOptionAccount(
      options.accountPreviousConversions?.name,
      '$equity:Conversions:Previous',
      prefixes,
    ),
    accountCurrentEarnings: _resolvedOptionAccount(
      options.accountCurrentEarnings?.name,
      '$equity:Earnings:Current',
      prefixes,
    ),
    accountCurrentConversions: _resolvedOptionAccount(
      options.accountCurrentConversions?.name,
      '$equity:Conversions:Current',
      prefixes,
    ),
    accountUnrealizedGains: _resolvedOptionAccount(
      options.accountUnrealizedGains?.name,
      '${prefixes.income}:Earnings:Unrealized',
      prefixes,
    ),
    accountRounding: options.accountRounding == null ? null : domainAccount(options.accountRounding!.name, prefixes),
    conversionCurrency: options.conversionCurrency == null
        ? d.Currency(name: 'NOTHING')
        : d.Currency(name: options.conversionCurrency!.name),
    displayPrecision: [
      for (final precision in options.displayPrecision)
        d.DisplayPrecision(key: _displayKey(precision.key), value: precision.value.resolved),
    ],
    inferredToleranceDefault: [
      for (final tolerance in options.inferredToleranceDefault)
        d.InferredTolerance(key: _currencyKey(tolerance.key), value: tolerance.value.resolved),
    ],
    toleranceMultiplier: options.toleranceMultiplier?.resolved ?? Decimal.parse('0.5'),
    inferToleranceFromCost: options.inferToleranceFromCost ?? false,
    documents: List<String>.from(options.documents),
    operatingCurrency: [for (final currency in options.operatingCurrency) d.Currency(name: currency.name)],
    renderCommas: options.renderCommas ?? false,
    pluginProcessingMode: switch (options.pluginProcessingMode) {
      p.PluginProcessingMode.raw => d.PluginProcessingMode.raw,
      p.PluginProcessingMode.defaultMode || null => d.PluginProcessingMode.defaultMode,
    },
    longStringMaxlines: options.longStringMaxlines ?? 64,
    bookingMethod: mapBookingMethod(options.bookingMethod) ?? d.BookingMethod.strict,
    usePreciseInterpolation: options.usePreciseInterpolation ?? false,
    insertPythonpath: options.insertPythonpath ?? false,
    allowPipeSeparator: options.allowPipeSeparator ?? false,
    allowDeprecatedNoneForTagsAndLinks: options.allowDeprecatedNoneForTagsAndLinks ?? false,
  );
}

d.ProcessingInfo mapInfo(p.ProcessingInfo info) {
  return d.ProcessingInfo(
    filename: info.filename,
    include: List<String>.from(info.include),
    commodities: [for (final currency in info.commodities) d.Currency(name: currency.name)],
    plugin: [
      for (final plugin in info.plugin)
        d.Plugin(name: plugin.name, config: plugin.config, location: mapLocation(plugin.location)),
    ],
    displayContext: d.DisplayContext(
      precisions: [
        for (final precision in info.displayContext.precisions)
          d.DisplayPrecision(key: _displayKey(precision.key), value: precision.value.resolved),
      ],
    ),
    optionSettings: [
      for (final setting in info.optionSettings)
        d.OptionSetting(location: mapLocation(setting.location), key: setting.key, value: setting.value),
    ],
  );
}

d.BeanLocation mapLocation(p.BeanLocation location) =>
    d.BeanLocation(filename: location.filename, linenoBegin: location.linenoBegin, linenoEnd: location.linenoEnd);

d.Account domainAccount(String name, d.AccountPrefixes prefixes) =>
    d.Account(name: name, type: accountTypeFor(name, prefixes));

d.AccountType accountTypeFor(String name, d.AccountPrefixes prefixes) {
  if (_hasPrefix(name, prefixes.assets)) return d.AccountType.assets;
  if (_hasPrefix(name, prefixes.liabilities)) return d.AccountType.liabilities;
  if (_hasPrefix(name, prefixes.equity)) return d.AccountType.equity;
  if (_hasPrefix(name, prefixes.income)) return d.AccountType.income;
  if (_hasPrefix(name, prefixes.expenses)) return d.AccountType.expenses;
  return d.AccountType.assets;
}

d.BookingMethod? mapBookingMethod(p.BookingMethod? method) {
  return switch (method) {
    p.BookingMethod.strict => d.BookingMethod.strict,
    p.BookingMethod.strictWithSize => d.BookingMethod.strictWithSize,
    p.BookingMethod.none => d.BookingMethod.none,
    p.BookingMethod.average => d.BookingMethod.average,
    p.BookingMethod.fifo => d.BookingMethod.fifo,
    p.BookingMethod.lifo => d.BookingMethod.lifo,
    p.BookingMethod.hifo => d.BookingMethod.hifo,
    null => null,
  };
}

d.Account _resolvedOptionAccount(String? configured, String defaultName, d.AccountPrefixes prefixes) {
  if (configured == null) {
    return domainAccount(defaultName, prefixes);
  }
  // Parser stores a leaf or full name; join under equity when it has no colon.
  if (!configured.contains(':')) {
    return domainAccount('${prefixes.equity}:$configured', prefixes);
  }
  return domainAccount(configured, prefixes);
}

bool _hasPrefix(String name, String? prefix) {
  if (prefix == null || prefix.isEmpty) return false;
  return name == prefix || name.startsWith('$prefix:');
}

d.DisplayPrecisionKey _displayKey(p.DisplayPrecisionKey key) {
  return switch (key) {
    p.DisplayPrecisionCurrency(:final value) => d.DisplayPrecisionKey.currency(d.Currency(name: value.name)),
    p.DisplayPrecisionAll() => const d.DisplayPrecisionKey.all(),
    p.DisplayPrecisionPair(:final first, :final second) => d.DisplayPrecisionKey.pair(
      first: d.Currency(name: first.name),
      second: d.Currency(name: second.name),
    ),
  };
}

d.CurrencyKey _currencyKey(p.CurrencyKey key) {
  return switch (key) {
    p.CurrencyKeyCurrency(:final value) => d.CurrencyKey.currency(d.Currency(name: value.name)),
    p.CurrencyKeyAll() => const d.CurrencyKey.all(),
  };
}
