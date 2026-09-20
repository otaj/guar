// User options and parse-time by-products collected while reading a ledger.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/directive.dart';
import 'package:guar_parser/src/domain/location.dart';
import 'package:guar_parser/src/domain/number.dart';

part 'options.freezed.dart';

enum PluginProcessingMode { defaultMode, raw }

@freezed
abstract class AccountPrefixes with _$AccountPrefixes {
  const factory AccountPrefixes({
    String? assets,
    String? liabilities,
    String? equity,
    String? income,
    String? expenses,
  }) = _AccountPrefixes;
}

@freezed
abstract class Plugin with _$Plugin {
  const factory Plugin({required String name, required BeanLocation location, String? config}) = _Plugin;
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
  const factory DisplayPrecision({required DisplayPrecisionKey key, required BeanNumber value}) = _DisplayPrecision;
}

@freezed
abstract class InferredTolerance with _$InferredTolerance {
  const factory InferredTolerance({required CurrencyKey key, required BeanNumber value}) = _InferredTolerance;
}

@freezed
abstract class DisplayContext with _$DisplayContext {
  const factory DisplayContext({@Default(<DisplayPrecision>[]) List<DisplayPrecision> precisions}) = _DisplayContext;
}

@freezed
abstract class ProcessingInfo with _$ProcessingInfo {
  const factory ProcessingInfo({
    String? filename,
    @Default(<String>[]) List<String> include,
    @Default(<Currency>[]) List<Currency> commodities,
    @Default(<Plugin>[]) List<Plugin> plugin,
    @Default(DisplayContext()) DisplayContext displayContext,
    @Default(<OptionSetting>[]) List<OptionSetting> optionSettings,
  }) = _ProcessingInfo;
}

@freezed
abstract class LedgerOptions with _$LedgerOptions {
  const factory LedgerOptions({
    @Default(AccountPrefixes()) AccountPrefixes accountPrefixes,
    String? title,
    Account? accountPreviousBalances,
    Account? accountPreviousEarnings,
    Account? accountPreviousConversions,
    Account? accountCurrentEarnings,
    Account? accountCurrentConversions,
    Account? accountUnrealizedGains,
    Account? accountRounding,
    Currency? conversionCurrency,
    @Default(<DisplayPrecision>[]) List<DisplayPrecision> displayPrecision,
    @Default(<InferredTolerance>[]) List<InferredTolerance> inferredToleranceDefault,
    BeanNumber? inferredToleranceMultiplier,
    BeanNumber? toleranceMultiplier,
    bool? inferToleranceFromCost,
    @Default(<String>[]) List<String> documents,
    @Default(<Currency>[]) List<Currency> operatingCurrency,
    bool? renderCommas,
    PluginProcessingMode? pluginProcessingMode,
    int? longStringMaxlines,
    BookingMethod? bookingMethod,
    bool? usePreciseInterpolation,
    bool? insertPythonpath,
    bool? allowPipeSeparator,
    bool? allowDeprecatedNoneForTagsAndLinks,
  }) = _LedgerOptions;
}
