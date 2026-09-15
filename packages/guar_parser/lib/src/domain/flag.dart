// Transaction or posting flag as stored after parsing.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation.dart';

part 'flag.freezed.dart';

enum SpecialFlag { asterisk, exclamation, hash, ampersand, question, percent }

@Freezed(when: FreezedWhenOptions.none, map: FreezedMapOptions.none)
sealed class Flag with _$Flag {
  const factory Flag.special(SpecialFlag value) = SpecialFlagValue;

  factory Flag.letter(String value) {
    ensureLetterFlag(value);
    return Flag._letter(value);
  }

  const factory Flag._letter(String value) = LetterFlag;
}
