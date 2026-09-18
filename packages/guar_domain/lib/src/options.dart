// Ledger options and processing by-products on a booked ledger.

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'directive.dart';
import 'location.dart';

part 'options.freezed.dart';

enum PluginProcessingMode { defaultMode, raw }

@freezed
abstract class AccountPrefixes with _$AccountPrefixes {
  const AccountPrefixes._();

  const factory AccountPrefixes({
    @Default('Assets') String assets,
    @Default('Liabilities') String liabilities,
    @Default('Equity') String equity,
    @Default('Income') String income,
    @Default('Expenses') String expenses,
  }) = _AccountPrefixes;

  AccountType typeFor(String name) {
    if (isAccountOrSubaccount(name, assets)) return AccountType.assets;
    if (isAccountOrSubaccount(name, liabilities)) return AccountType.liabilities;
    if (isAccountOrSubaccount(name, equity)) return AccountType.equity;
    if (isAccountOrSubaccount(name, income)) return AccountType.income;
    if (isAccountOrSubaccount(name, expenses)) return AccountType.expenses;
    return AccountType.assets;
  }

  Account account(String name) => Account(name: name, type: typeFor(name));
}

@freezed
abstract class Plugin with _$Plugin {
  const factory Plugin({required String name, String? config, required BeanLocation location}) = _Plugin;
}

@freezed
abstract class OptionSetting with _$OptionSetting {
  const factory OptionSetting({required BeanLocation location, required String key, required String value}) =
      _OptionSetting;
}

@freezed
sealed class CurrencyKey with _$CurrencyKey {
  const factory CurrencyKey.currency(Currency value) = CurrencyKeyCurrency;
  const factory CurrencyKey.all() = CurrencyKeyAll;
}

@freezed
sealed class DisplayPrecisionKey with _$DisplayPrecisionKey {
  const factory DisplayPrecisionKey.currency(Currency value) = DisplayPrecisionCurrency;
  const factory DisplayPrecisionKey.all() = DisplayPrecisionAll;
  const factory DisplayPrecisionKey.pair({required Currency first, required Currency second}) = DisplayPrecisionPair;
}

@freezed
abstract class DisplayPrecision with _$DisplayPrecision {
  const factory DisplayPrecision({required DisplayPrecisionKey key, required Decimal value}) = _DisplayPrecision;
}

@freezed
abstract class InferredTolerance with _$InferredTolerance {
  const factory InferredTolerance({required CurrencyKey key, required Decimal value}) = _InferredTolerance;
}

@freezed
abstract class DisplayContext with _$DisplayContext {
  const factory DisplayContext({@Default([]) List<DisplayPrecision> precisions}) = _DisplayContext;
}

@freezed
abstract class ProcessingInfo with _$ProcessingInfo {
  const factory ProcessingInfo({
    String? filename,
    @Default([]) List<String> include,
    @Default([]) List<Currency> commodities,
    @Default([]) List<Plugin> plugin,
    @Default(DisplayContext()) DisplayContext displayContext,
    @Default([]) List<OptionSetting> optionSettings,
  }) = _ProcessingInfo;
}

class OptionNumber {
  OptionNumber({required this.verbatim, required this.value});

  final String verbatim;
  final Decimal value;

  @override
  bool operator ==(Object other) => other is OptionNumber && other.verbatim == verbatim && other.value == value;

  @override
  int get hashCode => Object.hash(verbatim, value);

  @override
  String toString() => verbatim;
}

final _defaultMultiplier = OptionNumber(verbatim: '0.5', value: Decimal.parse('0.5'));

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
abstract class LedgerOptions with _$LedgerOptions {
  const LedgerOptions._();

  const factory LedgerOptions._create({
    @Default(AccountPrefixes()) AccountPrefixes accountPrefixes,
    @Default('Beancount') String title,
    required Account accountPreviousBalances,
    required Account accountPreviousEarnings,
    required Account accountPreviousConversions,
    required Account accountCurrentEarnings,
    required Account accountCurrentConversions,
    required Account accountUnrealizedGains,
    Account? accountRounding,
    required Currency conversionCurrency,
    @Default([]) List<DisplayPrecision> displayPrecision,
    @Default([]) List<InferredTolerance> inferredToleranceDefault,
    required OptionNumber inferredToleranceMultiplier,
    required OptionNumber toleranceMultiplier,
    @Default(false) bool inferToleranceFromCost,
    @Default([]) List<String> documents,
    @Default([]) List<Currency> operatingCurrency,
    @Default(false) bool renderCommas,
    @Default(PluginProcessingMode.defaultMode) PluginProcessingMode pluginProcessingMode,
    @Default(64) int longStringMaxlines,
    @Default(BookingMethod.strict) BookingMethod bookingMethod,
    @Default(false) bool usePreciseInterpolation,
    @Default(false) bool insertPythonpath,
    @Default(false) bool allowPipeSeparator,
    @Default(false) bool allowDeprecatedNoneForTagsAndLinks,
  }) = _LedgerOptions;

  factory LedgerOptions({
    AccountPrefixes accountPrefixes = const AccountPrefixes(),
    String? title,
    Account? accountPreviousBalances,
    Account? accountPreviousEarnings,
    Account? accountPreviousConversions,
    Account? accountCurrentEarnings,
    Account? accountCurrentConversions,
    Account? accountUnrealizedGains,
    Account? accountRounding,
    Currency? conversionCurrency,
    List<DisplayPrecision> displayPrecision = const [],
    List<InferredTolerance> inferredToleranceDefault = const [],
    OptionNumber? inferredToleranceMultiplier,
    OptionNumber? toleranceMultiplier,
    bool? inferToleranceFromCost,
    List<String> documents = const [],
    List<Currency> operatingCurrency = const [],
    bool? renderCommas,
    PluginProcessingMode? pluginProcessingMode,
    int? longStringMaxlines,
    BookingMethod? bookingMethod,
    bool? usePreciseInterpolation,
    bool? insertPythonpath,
    bool? allowPipeSeparator,
    bool? allowDeprecatedNoneForTagsAndLinks,
  }) {
    final equity = accountPrefixes.equity;
    return LedgerOptions._create(
      accountPrefixes: accountPrefixes,
      title: title ?? 'Beancount',
      accountPreviousBalances:
          accountPreviousBalances ?? Account(name: '$equity:Opening-Balances', type: AccountType.equity),
      accountPreviousEarnings:
          accountPreviousEarnings ?? Account(name: '$equity:Earnings:Previous', type: AccountType.equity),
      accountPreviousConversions:
          accountPreviousConversions ?? Account(name: '$equity:Conversions:Previous', type: AccountType.equity),
      accountCurrentEarnings:
          accountCurrentEarnings ?? Account(name: '$equity:Earnings:Current', type: AccountType.equity),
      accountCurrentConversions:
          accountCurrentConversions ?? Account(name: '$equity:Conversions:Current', type: AccountType.equity),
      accountUnrealizedGains:
          accountUnrealizedGains ??
          Account(name: '${accountPrefixes.income}:Earnings:Unrealized', type: AccountType.income),
      accountRounding: accountRounding,
      conversionCurrency: conversionCurrency ?? Currency(name: 'NOTHING'),
      displayPrecision: displayPrecision,
      inferredToleranceDefault: inferredToleranceDefault,
      inferredToleranceMultiplier: inferredToleranceMultiplier ?? _defaultMultiplier,
      toleranceMultiplier: toleranceMultiplier ?? _defaultMultiplier,
      inferToleranceFromCost: inferToleranceFromCost ?? false,
      documents: documents,
      operatingCurrency: operatingCurrency,
      renderCommas: renderCommas ?? false,
      pluginProcessingMode: pluginProcessingMode ?? PluginProcessingMode.defaultMode,
      longStringMaxlines: longStringMaxlines ?? 64,
      bookingMethod: bookingMethod ?? BookingMethod.strict,
      usePreciseInterpolation: usePreciseInterpolation ?? false,
      insertPythonpath: insertPythonpath ?? false,
      allowPipeSeparator: allowPipeSeparator ?? false,
      allowDeprecatedNoneForTagsAndLinks: allowDeprecatedNoneForTagsAndLinks ?? false,
    );
  }
}
