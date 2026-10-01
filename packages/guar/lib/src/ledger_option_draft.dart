// Turns settings-field text into booked LedgerOptions, or a reason it cannot be saved.

import 'package:decimal/decimal.dart';
import 'package:guar_domain/guar_domain.dart';

class OptionInputs {
  const OptionInputs({
    required this.title,
    required this.documents,
    required this.operatingCurrencies,
    required this.conversionCurrency,
    required this.renderCommas,
    required this.longStringMaxlines,
    required this.pluginProcessingMode,
    required this.insertPythonpath,
    required this.allowPipeSeparator,
    required this.allowDeprecatedNoneForTagsAndLinks,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.income,
    required this.expenses,
    required this.previousBalances,
    required this.previousEarnings,
    required this.previousConversions,
    required this.currentEarnings,
    required this.currentConversions,
    required this.unrealizedGains,
    required this.rounding,
    required this.bookingMethod,
    required this.usePreciseInterpolation,
    required this.inferToleranceFromCost,
    required this.toleranceMultiplier,
    required this.inferredToleranceMultiplier,
    required this.inferredTolerances,
    required this.displayPrecisions,
    required this.baselinePrefixes,
  });

  final String title;
  final List<String> documents;
  final List<String> operatingCurrencies;
  final String conversionCurrency;
  final bool renderCommas;
  final String longStringMaxlines;
  final PluginProcessingMode pluginProcessingMode;
  final bool insertPythonpath;
  final bool allowPipeSeparator;
  final bool allowDeprecatedNoneForTagsAndLinks;
  final String assets;
  final String liabilities;
  final String equity;
  final String income;
  final String expenses;
  final String previousBalances;
  final String previousEarnings;
  final String previousConversions;
  final String currentEarnings;
  final String currentConversions;
  final String unrealizedGains;
  final String rounding;
  final BookingMethod bookingMethod;
  final bool usePreciseInterpolation;
  final bool inferToleranceFromCost;
  final String toleranceMultiplier;
  final String inferredToleranceMultiplier;
  final List<({String key, String value})> inferredTolerances;
  final List<({String key, String value})> displayPrecisions;
  final AccountPrefixes baselinePrefixes;
}

class DraftedOptions {
  const DraftedOptions.ok(this.options, this.accounts) : error = null;

  const DraftedOptions.bad(this.error) : options = null, accounts = const <String, String>{};

  final LedgerOptions? options;
  final String? error;
  final Map<String, String> accounts;
}

DraftedOptions draftLedgerOptions(OptionInputs input) {
  final String? quoted = _quoted(<String>[
    input.title,
    input.conversionCurrency,
    input.longStringMaxlines,
    input.assets,
    input.liabilities,
    input.equity,
    input.income,
    input.expenses,
    input.previousBalances,
    input.previousEarnings,
    input.previousConversions,
    input.currentEarnings,
    input.currentConversions,
    input.unrealizedGains,
    input.rounding,
    input.toleranceMultiplier,
    input.inferredToleranceMultiplier,
    ...input.documents,
    ...input.operatingCurrencies,
    for (final ({String key, String value}) row in input.inferredTolerances) ...<String>[row.key, row.value],
    for (final ({String key, String value}) row in input.displayPrecisions) ...<String>[row.key, row.value],
  ]);
  if (quoted != null) {
    return DraftedOptions.bad(quoted);
  }

  final AccountPrefixes prefixes = AccountPrefixes(
    assets: input.assets,
    liabilities: input.liabilities,
    equity: input.equity,
    income: input.income,
    expenses: input.expenses,
  );
  if (<String>[prefixes.assets, prefixes.liabilities, prefixes.equity, prefixes.income, prefixes.expenses].any(
    (String name) => !isValidAccountRoot(name),
  )) {
    return const DraftedOptions.bad('not a valid account name');
  }

  final LedgerOptions previous = LedgerOptions(accountPrefixes: input.baselinePrefixes);
  final LedgerOptions next = LedgerOptions(accountPrefixes: prefixes);
  final Map<String, String> accounts = <String, String>{
    'previousBalances': _snap(input.previousBalances, previous.accountPreviousBalances, next.accountPreviousBalances),
    'previousEarnings': _snap(input.previousEarnings, previous.accountPreviousEarnings, next.accountPreviousEarnings),
    'previousConversions': _snap(
      input.previousConversions,
      previous.accountPreviousConversions,
      next.accountPreviousConversions,
    ),
    'currentEarnings': _snap(input.currentEarnings, previous.accountCurrentEarnings, next.accountCurrentEarnings),
    'currentConversions': _snap(
      input.currentConversions,
      previous.accountCurrentConversions,
      next.accountCurrentConversions,
    ),
    'unrealizedGains': _snap(input.unrealizedGains, previous.accountUnrealizedGains, next.accountUnrealizedGains),
  };

  Account? account(String name) {
    if (name.isEmpty) {
      return null;
    }
    if (!isValidAccountName(name)) {
      return null;
    }
    return prefixes.account(name);
  }

  if (accounts.values.any((String name) => account(name) == null)) {
    return const DraftedOptions.bad('not a valid account name');
  }
  final String rounding = input.rounding.trim();
  if (rounding.isNotEmpty && account(rounding) == null) {
    return const DraftedOptions.bad('not a valid account name');
  }

  final List<Currency> operating = <Currency>[];
  for (final String name in input.operatingCurrencies.map((String name) => name.trim())) {
    if (name.isEmpty) {
      continue;
    }
    final Currency? currency = _currency(name);
    if (currency == null) {
      return const DraftedOptions.bad('not a valid currency code');
    }
    operating.add(currency);
  }
  final Currency? conversion = _currency(input.conversionCurrency.trim());
  if (conversion == null) {
    return const DraftedOptions.bad('not a valid currency code');
  }

  final int? maxLines = int.tryParse(input.longStringMaxlines.trim());
  if (maxLines == null || maxLines < 0) {
    return const DraftedOptions.bad('Enter a whole number zero or greater');
  }
  final OptionNumber? tolerance = _number(input.toleranceMultiplier);
  final OptionNumber? inferred = _number(input.inferredToleranceMultiplier);
  if (tolerance == null || inferred == null) {
    return const DraftedOptions.bad('Enter a number');
  }

  final List<InferredTolerance> tolerances = <InferredTolerance>[];
  for (final ({String key, String value}) row in input.inferredTolerances) {
    if (row.key.trim().isEmpty && row.value.trim().isEmpty) {
      continue;
    }
    final InferredTolerance? parsed = _tolerance(row.key.trim(), row.value.trim());
    if (parsed == null) {
      return const DraftedOptions.bad('Enter a number');
    }
    tolerances.add(parsed);
  }
  final List<DisplayPrecision> precisions = <DisplayPrecision>[];
  for (final ({String key, String value}) row in input.displayPrecisions) {
    if (row.key.trim().isEmpty && row.value.trim().isEmpty) {
      continue;
    }
    final DisplayPrecision? parsed = _precision(row.key.trim(), row.value.trim());
    if (parsed == null) {
      return const DraftedOptions.bad('Enter a number');
    }
    precisions.add(parsed);
  }

  return DraftedOptions.ok(
    LedgerOptions(
      accountPrefixes: prefixes,
      title: input.title,
      documents: <String>[
        for (final String document in input.documents)
          if (document.trim().isNotEmpty) document,
      ],
      operatingCurrency: operating,
      conversionCurrency: conversion,
      renderCommas: input.renderCommas,
      longStringMaxlines: maxLines,
      pluginProcessingMode: input.pluginProcessingMode,
      insertPythonpath: input.insertPythonpath,
      allowPipeSeparator: input.allowPipeSeparator,
      allowDeprecatedNoneForTagsAndLinks: input.allowDeprecatedNoneForTagsAndLinks,
      accountPreviousBalances: account(accounts['previousBalances']!)!,
      accountPreviousEarnings: account(accounts['previousEarnings']!)!,
      accountPreviousConversions: account(accounts['previousConversions']!)!,
      accountCurrentEarnings: account(accounts['currentEarnings']!)!,
      accountCurrentConversions: account(accounts['currentConversions']!)!,
      accountUnrealizedGains: account(accounts['unrealizedGains']!)!,
      accountRounding: rounding.isEmpty ? null : account(rounding),
      bookingMethod: input.bookingMethod,
      usePreciseInterpolation: input.usePreciseInterpolation,
      inferToleranceFromCost: input.inferToleranceFromCost,
      toleranceMultiplier: tolerance,
      inferredToleranceMultiplier: inferred,
      inferredToleranceDefault: tolerances,
      displayPrecision: precisions,
    ),
    accounts,
  );
}

String _snap(String current, Account previous, Account updated) => current == previous.name ? updated.name : current;

String? _quoted(List<String> values) {
  for (final String value in values) {
    if (value.contains('"')) {
      return 'Quotes cannot be stored in an option value';
    }
  }
  return null;
}

Currency? _currency(String name) {
  if (!isValidCurrencyName(name)) {
    return null;
  }
  return Currency(name: name);
}

OptionNumber? _number(String text) {
  final String verbatim = text.trim();
  try {
    return OptionNumber(verbatim: verbatim, value: Decimal.parse(verbatim));
  } on FormatException {
    return null;
  }
}

InferredTolerance? _tolerance(String key, String value) {
  final OptionNumber? number = _number(value);
  if (number == null || key.isEmpty) {
    return null;
  }
  if (key == '*') {
    return InferredTolerance(key: const CurrencyKey.all(), value: number.value);
  }
  final Currency? currency = _currency(key);
  if (currency == null) {
    return null;
  }
  return InferredTolerance(key: CurrencyKey.currency(currency), value: number.value);
}

DisplayPrecision? _precision(String key, String value) {
  final OptionNumber? number = _number(value);
  if (number == null || key.isEmpty) {
    return null;
  }
  if (key == '*') {
    return DisplayPrecision(key: const DisplayPrecisionKey.all(), value: number.value);
  }
  final int slash = key.indexOf('/');
  if (slash > 0 && slash < key.length - 1) {
    final Currency? first = _currency(key.substring(0, slash));
    final Currency? second = _currency(key.substring(slash + 1));
    if (first == null || second == null) {
      return null;
    }
    return DisplayPrecision(
      key: DisplayPrecisionKey.pair(first: first, second: second),
      value: number.value,
    );
  }
  final Currency? currency = _currency(key);
  if (currency == null) {
    return null;
  }
  return DisplayPrecision(key: DisplayPrecisionKey.currency(currency), value: number.value);
}
