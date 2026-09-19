// Top-level parse result: dated directives or errors by default; recover keeps both. Warnings are non-fatal.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:guar_parser/src/domain/directive.dart';
import 'package:guar_parser/src/domain/options.dart';

part 'parsed_ledger.freezed.dart';

@freezed
sealed class ParsedLedger with _$ParsedLedger {
  const factory ParsedLedger.directives({
    required List<ParsedDirective> directives,
    @Default(<dynamic>[]) List<ParseError> errors,
    @Default(<dynamic>[]) List<ParseWarning> warnings,
    @Default(LedgerOptions()) LedgerOptions options,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = ParsedLedgerDirectives;

  const factory ParsedLedger.errors({
    required List<ParseError> errors,
    @Default(<dynamic>[]) List<ParseWarning> warnings,
    @Default(LedgerOptions()) LedgerOptions options,
    @Default(ProcessingInfo()) ProcessingInfo info,
  }) = ParsedLedgerErrors;
}
