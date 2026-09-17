// Callable plugins injected into the booking pipeline by name.

import 'package:guar_domain/guar_domain.dart';

typedef BookPluginResult = ({List<Directive> directives, List<ProcessingError> errors});

typedef BookPlugin =
    BookPluginResult Function(List<Directive> directives, LedgerOptions options, ProcessingInfo info, String? config);
