// Top-level booked ledger: directives or errors by default; recover keeps both.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'directive.dart';
import 'options.dart';

part 'ledger.freezed.dart';

@freezed
sealed class Ledger with _$Ledger {
  const factory Ledger.directives({
    required List<Directive> directives,
    @Default([]) List<ProcessingError> errors,
    required LedgerOptions options,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = LedgerDirectives;

  const factory Ledger.errors({
    required List<ProcessingError> errors,
    required LedgerOptions options,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = LedgerErrors;
}
