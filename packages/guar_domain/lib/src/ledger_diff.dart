// Structural diff of two booked ledgers, including options and processing info.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/account.dart';
import 'package:guar_domain/src/directive.dart';
import 'package:guar_domain/src/options.dart';

part 'ledger_diff.freezed.dart';

@immutable
class FieldChange<T> {
  const FieldChange({required this.left, required this.right});

  final T left;
  final T right;

  @override
  bool operator ==(Object other) => other is FieldChange<T> && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

@immutable
class ListDiff<T> {
  const ListDiff({this.onlyInLeft = const <Never>[], this.onlyInRight = const <Never>[]});

  final List<T> onlyInLeft;
  final List<T> onlyInRight;

  bool get isEmpty => onlyInLeft.isEmpty && onlyInRight.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ListDiff<T> && _listEquals(other.onlyInLeft, onlyInLeft) && _listEquals(other.onlyInRight, onlyInRight);

  @override
  int get hashCode => Object.hash(Object.hashAll(onlyInLeft), Object.hashAll(onlyInRight));
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

@freezed
abstract class OptionsDiff with _$OptionsDiff {
  const factory OptionsDiff({
    FieldChange<AccountPrefixes>? accountPrefixes,
    FieldChange<String>? title,
    FieldChange<Account>? accountPreviousBalances,
    FieldChange<Account>? accountPreviousEarnings,
    FieldChange<Account>? accountPreviousConversions,
    FieldChange<Account>? accountCurrentEarnings,
    FieldChange<Account>? accountCurrentConversions,
    FieldChange<Account>? accountUnrealizedGains,
    FieldChange<Account?>? accountRounding,
    FieldChange<Currency>? conversionCurrency,
    @Default(ListDiff<DisplayPrecision>()) ListDiff<DisplayPrecision> displayPrecision,
    @Default(ListDiff<InferredTolerance>()) ListDiff<InferredTolerance> inferredToleranceDefault,
    FieldChange<OptionNumber>? inferredToleranceMultiplier,
    FieldChange<OptionNumber>? toleranceMultiplier,
    FieldChange<bool>? inferToleranceFromCost,
    @Default(ListDiff<String>()) ListDiff<String> documents,
    @Default(ListDiff<Currency>()) ListDiff<Currency> operatingCurrency,
    FieldChange<bool>? renderCommas,
    FieldChange<PluginProcessingMode>? pluginProcessingMode,
    FieldChange<int>? longStringMaxlines,
    FieldChange<BookingMethod>? bookingMethod,
    FieldChange<bool>? usePreciseInterpolation,
    FieldChange<bool>? insertPythonpath,
    FieldChange<bool>? allowPipeSeparator,
    FieldChange<bool>? allowDeprecatedNoneForTagsAndLinks,
  }) = _OptionsDiff;
  const OptionsDiff._();

  bool get isEmpty =>
      accountPrefixes == null &&
      title == null &&
      accountPreviousBalances == null &&
      accountPreviousEarnings == null &&
      accountPreviousConversions == null &&
      accountCurrentEarnings == null &&
      accountCurrentConversions == null &&
      accountUnrealizedGains == null &&
      accountRounding == null &&
      conversionCurrency == null &&
      displayPrecision.isEmpty &&
      inferredToleranceDefault.isEmpty &&
      inferredToleranceMultiplier == null &&
      toleranceMultiplier == null &&
      inferToleranceFromCost == null &&
      documents.isEmpty &&
      operatingCurrency.isEmpty &&
      renderCommas == null &&
      pluginProcessingMode == null &&
      longStringMaxlines == null &&
      bookingMethod == null &&
      usePreciseInterpolation == null &&
      insertPythonpath == null &&
      allowPipeSeparator == null &&
      allowDeprecatedNoneForTagsAndLinks == null;
}

@freezed
abstract class InfoDiff with _$InfoDiff {
  const factory InfoDiff({
    @Default(ListDiff<String>()) ListDiff<String> include,
    @Default(ListDiff<Currency>()) ListDiff<Currency> commodities,
    @Default(ListDiff<Plugin>()) ListDiff<Plugin> plugin,
    @Default(ListDiff<DisplayPrecision>()) ListDiff<DisplayPrecision> displayContext,
    @Default(ListDiff<OptionSetting>()) ListDiff<OptionSetting> optionSettings,
  }) = _InfoDiff;
  const InfoDiff._();

  bool get isEmpty =>
      include.isEmpty && commodities.isEmpty && plugin.isEmpty && displayContext.isEmpty && optionSettings.isEmpty;
}

@freezed
abstract class LedgerDiff with _$LedgerDiff {
  const factory LedgerDiff({
    @Default(<dynamic>[]) List<Directive> onlyInLeft,
    @Default(<dynamic>[]) List<Directive> onlyInRight,
    @Default(<dynamic>[]) List<ProcessingError> errorsOnlyInLeft,
    @Default(<dynamic>[]) List<ProcessingError> errorsOnlyInRight,
    @Default(<dynamic>[]) List<ProcessingWarning> warningsOnlyInLeft,
    @Default(<dynamic>[]) List<ProcessingWarning> warningsOnlyInRight,
    @Default(OptionsDiff()) OptionsDiff options,
    @Default(InfoDiff()) InfoDiff info,
  }) = _LedgerDiff;
  const LedgerDiff._();

  bool get isEmpty =>
      onlyInLeft.isEmpty &&
      onlyInRight.isEmpty &&
      errorsOnlyInLeft.isEmpty &&
      errorsOnlyInRight.isEmpty &&
      warningsOnlyInLeft.isEmpty &&
      warningsOnlyInRight.isEmpty &&
      options.isEmpty &&
      info.isEmpty;
}
