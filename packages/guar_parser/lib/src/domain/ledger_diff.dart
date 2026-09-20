// Structural diff of two parsed ledgers, including options and processing info.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/account.dart';
import 'package:guar_parser/src/domain/directive.dart';
import 'package:guar_parser/src/domain/number.dart';
import 'package:guar_parser/src/domain/options.dart';

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
abstract class ChangedDirective with _$ChangedDirective {
  const factory ChangedDirective({required ParsedDirective left, required ParsedDirective right}) = _ChangedDirective;
}

@freezed
abstract class OptionsDiff with _$OptionsDiff {
  const factory OptionsDiff({
    FieldChange<AccountPrefixes>? accountPrefixes,
    FieldChange<String?>? title,
    FieldChange<Account?>? accountPreviousBalances,
    FieldChange<Account?>? accountPreviousEarnings,
    FieldChange<Account?>? accountPreviousConversions,
    FieldChange<Account?>? accountCurrentEarnings,
    FieldChange<Account?>? accountCurrentConversions,
    FieldChange<Account?>? accountUnrealizedGains,
    FieldChange<Account?>? accountRounding,
    FieldChange<Currency?>? conversionCurrency,
    @Default(ListDiff<DisplayPrecision>()) ListDiff<DisplayPrecision> displayPrecision,
    @Default(ListDiff<InferredTolerance>()) ListDiff<InferredTolerance> inferredToleranceDefault,
    FieldChange<BeanNumber?>? inferredToleranceMultiplier,
    FieldChange<BeanNumber?>? toleranceMultiplier,
    FieldChange<bool?>? inferToleranceFromCost,
    @Default(ListDiff<String>()) ListDiff<String> documents,
    @Default(ListDiff<Currency>()) ListDiff<Currency> operatingCurrency,
    FieldChange<bool?>? renderCommas,
    FieldChange<PluginProcessingMode?>? pluginProcessingMode,
    FieldChange<int?>? longStringMaxlines,
    FieldChange<BookingMethod?>? bookingMethod,
    FieldChange<bool?>? usePreciseInterpolation,
    FieldChange<bool?>? insertPythonpath,
    FieldChange<bool?>? allowPipeSeparator,
    FieldChange<bool?>? allowDeprecatedNoneForTagsAndLinks,
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
    FieldChange<String?>? filename,
    @Default(ListDiff<String>()) ListDiff<String> include,
    @Default(ListDiff<Currency>()) ListDiff<Currency> commodities,
    @Default(ListDiff<Plugin>()) ListDiff<Plugin> plugin,
    @Default(ListDiff<DisplayPrecision>()) ListDiff<DisplayPrecision> displayContext,
    @Default(ListDiff<OptionSetting>()) ListDiff<OptionSetting> optionSettings,
  }) = _InfoDiff;
  const InfoDiff._();

  bool get isEmpty =>
      filename == null &&
      include.isEmpty &&
      commodities.isEmpty &&
      plugin.isEmpty &&
      displayContext.isEmpty &&
      optionSettings.isEmpty;
}

@freezed
abstract class LedgerDiff with _$LedgerDiff {
  const factory LedgerDiff({
    @Default(<ParsedDirective>[]) List<ParsedDirective> onlyInLeft,
    @Default(<ParsedDirective>[]) List<ParsedDirective> onlyInRight,
    @Default(<ChangedDirective>[]) List<ChangedDirective> changed,
    @Default(<ParseError>[]) List<ParseError> errorsOnlyInLeft,
    @Default(<ParseError>[]) List<ParseError> errorsOnlyInRight,
    @Default(<ParseWarning>[]) List<ParseWarning> warningsOnlyInLeft,
    @Default(<ParseWarning>[]) List<ParseWarning> warningsOnlyInRight,
    @Default(OptionsDiff()) OptionsDiff options,
    @Default(InfoDiff()) InfoDiff info,
  }) = _LedgerDiff;
  const LedgerDiff._();

  bool get isEmpty =>
      onlyInLeft.isEmpty &&
      onlyInRight.isEmpty &&
      changed.isEmpty &&
      errorsOnlyInLeft.isEmpty &&
      errorsOnlyInRight.isEmpty &&
      warningsOnlyInLeft.isEmpty &&
      warningsOnlyInRight.isEmpty &&
      options.isEmpty &&
      info.isEmpty;
}
