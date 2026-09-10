// Structural diff of two parsed ledgers, including options and processing info.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'account.dart';
import 'directive.dart';
import 'number.dart';
import 'options.dart';

part 'ledger_diff.freezed.dart';

class FieldChange<T> {
  const FieldChange({required this.left, required this.right});

  final T left;
  final T right;

  @override
  bool operator ==(Object other) {
    return other is FieldChange<T> && other.left == left && other.right == right;
  }

  @override
  int get hashCode => Object.hash(left, right);
}

class ListDiff<T> {
  const ListDiff({this.onlyInLeft = const [], this.onlyInRight = const []});

  final List<T> onlyInLeft;
  final List<T> onlyInRight;

  bool get isEmpty => onlyInLeft.isEmpty && onlyInRight.isEmpty;

  @override
  bool operator ==(Object other) {
    return other is ListDiff<T> &&
        _listEquals(other.onlyInLeft, onlyInLeft) &&
        _listEquals(other.onlyInRight, onlyInRight);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(onlyInLeft), Object.hashAll(onlyInRight));
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
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
  const OptionsDiff._();

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
  const InfoDiff._();

  const factory InfoDiff({
    FieldChange<String?>? filename,
    @Default(ListDiff<String>()) ListDiff<String> include,
    @Default(ListDiff<Currency>()) ListDiff<Currency> commodities,
    @Default(ListDiff<Plugin>()) ListDiff<Plugin> plugin,
    @Default(ListDiff<DisplayPrecision>()) ListDiff<DisplayPrecision> displayContext,
    @Default(ListDiff<OptionSetting>()) ListDiff<OptionSetting> optionSettings,
  }) = _InfoDiff;

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
  const LedgerDiff._();

  const factory LedgerDiff({
    @Default([]) List<ParsedDirective> onlyInLeft,
    @Default([]) List<ParsedDirective> onlyInRight,
    @Default([]) List<ChangedDirective> changed,
    @Default([]) List<ParseError> errorsOnlyInLeft,
    @Default([]) List<ParseError> errorsOnlyInRight,
    @Default(OptionsDiff()) OptionsDiff options,
    @Default(InfoDiff()) InfoDiff info,
  }) = _LedgerDiff;

  bool get isEmpty =>
      onlyInLeft.isEmpty &&
      onlyInRight.isEmpty &&
      changed.isEmpty &&
      errorsOnlyInLeft.isEmpty &&
      errorsOnlyInRight.isEmpty &&
      options.isEmpty &&
      info.isEmpty;
}
