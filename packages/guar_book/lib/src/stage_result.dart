// Shared result of a booking or stage pass that may accumulate errors.

import 'package:guar_domain/guar_domain.dart';

class StageResult {
  StageResult({required this.directives, this.errors = const []});

  final List<Directive> directives;
  final List<ProcessingError> errors;

  bool get hasErrors => errors.isNotEmpty;
}
