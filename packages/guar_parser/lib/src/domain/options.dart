// User options and parse-time by-products collected while reading a ledger.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'directive.dart';
import 'number.dart';

part 'options.freezed.dart';

enum PluginProcessingMode { defaultMode, raw }

@freezed
abstract class AccountPrefixes with _$AccountPrefixes {
  const factory AccountPrefixes({
    @Default('Assets') String assets,
    @Default('Liabilities') String liabilities,
    @Default('Equity') String equity,
    @Default('Income') String income,
    @Default('Expenses') String expenses,
  }) = _AccountPrefixes;
}

@freezed
abstract class Plugin with _$Plugin {
  const factory Plugin({required String name, String? config}) = _Plugin;
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
  const factory DisplayPrecision({required DisplayPrecisionKey key, required BeanNumber value}) = _DisplayPrecision;
}

@freezed
abstract class InferredTolerance with _$InferredTolerance {
  const factory InferredTolerance({required CurrencyKey key, required BeanNumber value}) = _InferredTolerance;
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
  }) = _ProcessingInfo;
}

@freezed
abstract class LedgerOptions with _$LedgerOptions {
  const factory LedgerOptions({
    @Default(AccountPrefixes()) AccountPrefixes accountPrefixes,
    @Default('Untitled Beancount file') String title,
    @Default(Account(name: 'Opening-Balances')) Account accountPreviousBalances,
    @Default(Account(name: 'Earnings:Previous')) Account accountPreviousEarnings,
    @Default(Account(name: 'Conversions:Previous')) Account accountPreviousConversions,
    @Default(Account(name: 'Earnings:Current')) Account accountCurrentEarnings,
    @Default(Account(name: 'Conversions:Current')) Account accountCurrentConversions,
    @Default(Account(name: 'Earnings:Unrealized')) Account accountUnrealizedGains,
    Account? accountRounding,
    @Default(Currency(name: 'INR')) Currency conversionCurrency,
    @Default([]) List<DisplayPrecision> displayPrecision,
    @Default([]) List<InferredTolerance> inferredToleranceDefault,
    BeanNumber? toleranceMultiplier,
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
}
