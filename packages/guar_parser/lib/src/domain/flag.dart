// Transaction or posting flag as stored after parsing.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'flag.freezed.dart';

enum SpecialFlag { asterisk, exclamation, hash, ampersand, question, percent }

@freezed
sealed class Flag with _$Flag {
  const factory Flag.special(SpecialFlag value) = SpecialFlagValue;
  const factory Flag.letter(String value) = LetterFlag;
}
