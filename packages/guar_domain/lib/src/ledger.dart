// Top-level booked ledger: directives or errors by default; recover keeps both. Warnings are non-fatal.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_domain/src/directive.dart';
import 'package:guar_domain/src/options.dart';

part 'ledger.freezed.dart';

@freezed
sealed class Ledger with _$Ledger {
  const factory Ledger.directives({
    required List<Directive> directives,
    required LedgerOptions options,
    @Default(<dynamic>[]) List<ProcessingError> errors,
    @Default(<dynamic>[]) List<ProcessingWarning> warnings,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = LedgerDirectives;

  const factory Ledger.errors({
    required List<ProcessingError> errors,
    required LedgerOptions options,
    @Default(<dynamic>[]) List<ProcessingWarning> warnings,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = LedgerErrors;
}
